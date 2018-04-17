import Foundation

// MARK: NSPopoverDelegate
extension XTSideBarDataSource: NSPopoverDelegate
{
  func popoverDidClose(_ notification: Notification)
  {
    statusPopover = nil
  }
}

// MARK: NSOutlineViewDataSource
extension XTSideBarDataSource: NSOutlineViewDataSource
{
  public func outlineView(_ outlineView: NSOutlineView,
                          numberOfChildrenOfItem item: Any?) -> Int
  {
    if item == nil {
      return roots.count
    }
    return (item as? XTSideBarItem)?.children.count ?? 0
  }
  
  public func outlineView(_ outlineView: NSOutlineView,
                          isItemExpandable item: Any) -> Bool
  {
    return (item as? XTSideBarItem)?.expandable ?? false
  }
  
  public func outlineView(_ outlineView: NSOutlineView,
                          child index: Int,
                          ofItem item: Any?) -> Any
  {
    if item == nil {
      return roots[index]
    }
    
    guard let sidebarItem = item as? XTSideBarItem,
          sidebarItem.children.count > index
    else { return XTSideBarItem(title: "") }
    
    return sidebarItem.children[index]
  }
}

// MARK: NSOutlineViewDelegate
extension XTSideBarDataSource: NSOutlineViewDelegate
{
  struct CellID
  {
    static let header = ¶"HeaderCell"
    static let data = ¶"DataCell"
  }
  
  public func outlineViewSelectionDidChange(_ notification: Notification)
  {
    guard let item = outline!.item(atRow: outline!.selectedRow)
                     as? XTSideBarItem,
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
    return item is XTSideBarGroupItem
  }

  public func outlineView(_ outlineView: NSOutlineView,
                          shouldShowOutlineCellForItem item: Any) -> Bool
  {
    // Don't hide the workspace group
    if (item as? XTSideBarGroupItem) === roots[0] {
      return false
    }
    
    return true
  }
  
  public func outlineView(_ outlineView: NSOutlineView,
                          shouldSelectItem item: Any) -> Bool
  {
    return (item as? XTSideBarItem)?.isSelectable ?? false
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
          let sideBarItem = item as? XTSideBarItem
    else { return nil }
    
    if item is XTSideBarGroupItem {
      guard let headerView = outlineView.makeView(
          withIdentifier: CellID.header, owner: nil) as? NSTableCellView
      else { return nil }
      
      headerView.textField?.stringValue = sideBarItem.title
      return headerView
    }
    else {
      guard let dataView = outlineView.makeView(
          withIdentifier: CellID.data, owner: nil) as? XTSidebarTableCellView
      else { return nil }
      
      let textField = dataView.textField!
      
      dataView.item = sideBarItem
      dataView.imageView?.image = sideBarItem.icon
      textField.stringValue = sideBarItem.displayTitle
      textField.isEditable = sideBarItem.editable
      textField.isSelectable = sideBarItem.isSelectable
      dataView.statusText.isHidden = true
      dataView.statusImage.isHidden = true
      dataView.statusButton.image = nil
      dataView.statusButton.action = nil
      if let image = statusImage(for: sideBarItem) {
        dataView.statusButton.image = image
        dataView.statusButton.target = self
        dataView.statusButton.action = #selector(self.showItemStatus(_:))
      }
      if sideBarItem is XTLocalBranchItem {
        configureLocalBranchItem(sideBarItem: sideBarItem, dataView: dataView)
      }
      dataView.statusButton.isHidden = dataView.statusButton.image == nil
      if sideBarItem.editable {
        textField.formatter = refFormatter
        textField.target = viewController
        textField.action =
            #selector(XTSidebarController.sidebarItemRenamed(_:))
      }
      
      let fontSize = textField.font?.pointSize ?? 12
      
      textField.font = sideBarItem.current
          ? NSFont.boldSystemFont(ofSize: fontSize)
          : NSFont.systemFont(ofSize: fontSize)

      if sideBarItem is XTStagingItem {
        configureStagingItem(sideBarItem: sideBarItem, dataView: dataView)
      }
      return dataView
    }
  }
  
  fileprivate func configureLocalBranchItem(sideBarItem: XTSideBarItem,
                                            dataView: XTSidebarTableCellView)
  {
    if let statusText = graphText(for: sideBarItem) {
      dataView.statusText.title = statusText
      dataView.statusText.isHidden = false
    }
    else if dataView.statusButton.image == nil {
      switch trackingBranchStatus(for: sideBarItem.title) {
        case .none:
          break
        case .missing(let tracking):
          dataView.statusButton.image =
                NSImage(named: .xtTrackingMissing)
          dataView.statusButton.toolTip = tracking + " (missing)"
          dataView.statusButton.target = self
          dataView.statusButton.action =
              #selector(self.missingTrackingBranch(_:))
        case .set(let tracking):
          dataView.statusButton.image = NSImage(named: .xtTracking)
          dataView.statusButton.toolTip = tracking
      }
    }
  }
  
  fileprivate func configureStagingItem(sideBarItem: XTSideBarItem,
                                        dataView: XTSidebarTableCellView)
  {
    let changes = sideBarItem.selection!.fileList.changes
    let stagedCount =
          changes.count(where: { $0.change != .unmodified })
    let unstagedCount =
          changes.count(where: { $0.unstagedChange != .unmodified })

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
    if let branchItem = item as? XTLocalBranchItem,
       branchItem.current {
      return SidebarCheckedRowView()
    }
    else if let remoteBranchItem = item as? XTRemoteBranchItem,
            let branchName = repository.currentBranch,
            let currentBranch = repository.localBranch(named: branchName),
            currentBranch.trackingBranchName == remoteBranchItem.remote + "/" +
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
extension XTSideBarDataSource: XTOutlineViewDelegate
{
  func outlineViewClickedSelectedRow(_ outline: NSOutlineView)
  {
    guard let selectedIndex = outline.selectedRowIndexes.first,
          let newSelectedItem = outline.item(atRow: selectedIndex)
                                as? XTSideBarItem
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
