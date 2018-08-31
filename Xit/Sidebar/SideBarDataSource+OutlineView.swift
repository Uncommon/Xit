import Foundation

// MARK: NSPopoverDelegate
extension SideBarDataSource: NSPopoverDelegate
{
  func popoverDidClose(_ notification: Notification)
  {
    statusPopover = nil
  }
}

// MARK: NSOutlineViewDataSource
extension SideBarDataSource: NSOutlineViewDataSource
{
  public func outlineView(_ outlineView: NSOutlineView,
                          numberOfChildrenOfItem item: Any?) -> Int
  {
    if item == nil {
      return roots.count
    }
    return (item as? SidebarItem)?.children.count ?? 0
  }
  
  public func outlineView(_ outlineView: NSOutlineView,
                          isItemExpandable item: Any) -> Bool
  {
    return (item as? SidebarItem)?.expandable ?? false
  }
  
  public func outlineView(_ outlineView: NSOutlineView,
                          child index: Int,
                          ofItem item: Any?) -> Any
  {
    if item == nil {
      return roots[index]
    }
    
    guard let sidebarItem = item as? SidebarItem,
          sidebarItem.children.count > index
    else { return SidebarItem(title: "") }
    
    return sidebarItem.children[index]
  }
}

// MARK: NSOutlineViewDelegate
extension SideBarDataSource: NSOutlineViewDelegate
{
  enum CellID
  {
    static let header = ¶"HeaderCell"
    static let data = ¶"DataCell"
  }
  
  public func outlineViewSelectionDidChange(_ notification: Notification)
  {
    guard let item = outline!.item(atRow: outline!.selectedRow)
                     as? SidebarItem,
          let selection = item.selection,
          let controller = outline!.window?.windowController
                           as? RepositoryController
    else { return }
    
    if controller.selection?.shaToSelect != selection.shaToSelect {
      controller.selection = selection
    }
  }

  public func outlineView(_ outlineView: NSOutlineView,
                          isGroupItem item: Any) -> Bool
  {
    return item is SideBarGroupItem
  }

  public func outlineView(_ outlineView: NSOutlineView,
                          shouldShowOutlineCellForItem item: Any) -> Bool
  {
    // Don't hide the workspace group
    if (item as? SideBarGroupItem) === roots[0] {
      return false
    }
    
    return true
  }
  
  public func outlineView(_ outlineView: NSOutlineView,
                          shouldSelectItem item: Any) -> Bool
  {
    return (item as? SidebarItem)?.isSelectable ?? false
  }

  public func outlineView(_ outlineView: NSOutlineView,
                          heightOfRowByItem item: Any) -> CGFloat
  {
    // Using this instead of setting rowSizeStyle because that prevents text
    // from displaying as bold (for the active branch).
   return 20.0
  }

  public func outlineView(_ outlineView: NSOutlineView,
                          viewFor tableColumn: NSTableColumn?,
                          item: Any) -> NSView?
  {
    guard repository != nil,
          let sideBarItem = item as? SidebarItem
    else { return nil }
    
    if item is SideBarGroupItem {
      guard let headerView = outlineView.makeView(
          withIdentifier: CellID.header, owner: nil) as? NSTableCellView
      else { return nil }
      
      headerView.textField?.stringValue = sideBarItem.title
      return headerView
    }
    else {
      guard let dataView = outlineView.makeView(
          withIdentifier: CellID.data, owner: nil) as? SidebarTableCellView
      else { return nil }
      
      let textField = dataView.textField!
      
      dataView.dataSource = self
      dataView.item = sideBarItem
      dataView.imageView?.image = sideBarItem.icon
      textField.stringValue = sideBarItem.displayTitle
      textField.isEditable = sideBarItem.editable
      textField.isSelectable = sideBarItem.isSelectable
      dataView.statusText.isHidden = true
      dataView.statusButton.image = nil
      dataView.statusButton.action = nil
      if let image = statusImage(for: sideBarItem) {
        dataView.statusButton.image = image
        dataView.statusButton.target = self
        dataView.statusButton.action = #selector(self.showItemStatus(_:))
      }
      if sideBarItem is LocalBranchSidebarItem {
        configureLocalBranchItem(sideBarItem: sideBarItem, dataView: dataView)
      }
      updatePullRequestButton(item: sideBarItem, view: dataView)
      dataView.buttonContainer.isHidden = dataView.statusButton.image == nil
      if sideBarItem.editable {
        textField.formatter = refFormatter
        textField.target = viewController
        textField.action =
            #selector(SidebarController.sidebarItemRenamed(_:))
      }
      
      let fontSize = textField.font?.pointSize ?? 12
      
      textField.font = sideBarItem.current
          ? NSFont.boldSystemFont(ofSize: fontSize)
          : NSFont.systemFont(ofSize: fontSize)

      if sideBarItem is StagingSidebarItem {
        configureStagingItem(sideBarItem: sideBarItem, dataView: dataView)
      }
      return dataView
    }
  }
  
  fileprivate func configureLocalBranchItem(sideBarItem: SidebarItem,
                                            dataView: SidebarTableCellView)
  {
    dataView.missingImage.isHidden = true
    if let statusText = graphText(for: sideBarItem) {
      dataView.statusText.title = statusText
      dataView.statusText.isHidden = false
    }
    else if dataView.statusButton.image == nil {
      switch trackingBranchStatus(for: sideBarItem.title) {
        case .none:
          break
        case .missing(let tracking):
          dataView.statusButton.image = NSImage(named: .xtTracking)
          dataView.statusButton.toolTip = tracking + " (missing)"
          dataView.statusButton.target = self
          dataView.statusButton.action =
              #selector(self.missingTrackingBranch(_:))
          dataView.missingImage.isHidden = false
          dataView.statusButton.isEnabled = true
          (dataView.statusButton.cell as? NSButtonCell)?
              .imageDimsWhenDisabled = true
        case .set(let tracking):
          dataView.statusButton.image = NSImage(named: .xtTracking)
          dataView.statusButton.toolTip = tracking
          dataView.statusButton.isEnabled = false
          (dataView.statusButton.cell as? NSButtonCell)?
              .imageDimsWhenDisabled = false
      }
    }
  }
  
  fileprivate func configureStagingItem(sideBarItem: SidebarItem,
                                        dataView: SidebarTableCellView)
  {
    let selection = sideBarItem.selection as! StagedUnstagedSelection
    let indexChanges = selection.fileList.changes
    let workspaceChanges = selection.unstagedFileList.changes
    let unmodifiedCounter: (FileChange) -> Bool = { $0.change != .unmodified }
    let stagedCount = indexChanges.count(where: unmodifiedCounter)
    let unstagedCount = workspaceChanges.count(where: unmodifiedCounter)

    if (stagedCount != 0) || (unstagedCount != 0) {
      dataView.statusText.title = "\(unstagedCount)▸\(stagedCount)"
      dataView.statusText.isHidden = false
    }
    else {
      dataView.statusText.isHidden = true
    }
  }
  
  public func outlineView(_ outlineView: NSOutlineView,
                          rowViewForItem item: Any) -> NSTableRowView?
  {
    if let branchItem = item as? LocalBranchSidebarItem,
       branchItem.current {
      return SidebarCheckedRowView()
    }
    else if let remoteBranchItem = item as? RemoteBranchSidebarItem,
            let branchName = repository.currentBranch,
            let currentBranch = repository.localBranch(named: branchName),
            currentBranch.trackingBranchName == remoteBranchItem.remoteName + "/" +
                                                remoteBranchItem.title {
      let rowView = SidebarCheckedRowView(
              imageName: .rightFacingTriangleTemplate,
              toolTip: "The active branch is tracking this remote branch")
      
      return rowView
    }
    else {
      return nil
    }
  }
}

// MARK: XTOutlineViewDelegate
extension SideBarDataSource: XTOutlineViewDelegate
{
  func outlineViewClickedSelectedRow(_ outline: NSOutlineView)
  {
    guard let selectedIndex = outline.selectedRowIndexes.first,
          let newSelectedItem = outline.item(atRow: selectedIndex)
                                as? SidebarItem
    else { return }
    
    if let controller = outline.window?.windowController
                        as? RepositoryController,
       let oldSelection = controller.selection,
       let newSelection = newSelectedItem.selection,
       oldSelection.shaToSelect == newSelection.shaToSelect &&
       type(of: oldSelection) != type(of: newSelection) {
      NotificationCenter.default.post(name: .XTReselectModel, object: repository)
    }
    selectedItem = newSelectedItem
  }
}
