import Foundation

// MARK: NSOutlineViewDataSource
extension SideBarDataSource: NSOutlineViewDataSource
{
  public func outlineView(_ outlineView: NSOutlineView,
                          numberOfChildrenOfItem item: Any?) -> Int
  {
    if item == nil {
      return model?.roots.count ?? 0
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
      return model.roots[index]
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
    if (item as? SideBarGroupItem) === model.rootItem(.workspace) {
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
      
      headerView.textField?.stringValue = sideBarItem.title.uppercased()
      return headerView
    }
    else {
      guard let dataView = outlineView.makeView(withIdentifier: CellID.data,
                                                owner: nil)
                           as? SidebarTableCellView
      else { return nil }
      
      let textField = dataView.textField!
      
      dataView.prDelegate = pullRequestManager
      dataView.item = sideBarItem
      dataView.imageView?.image = sideBarItem.icon
      textField.uiStringValue = sideBarItem.displayTitle
      textField.isEditable = sideBarItem.editable
      textField.isSelectable = sideBarItem.isSelectable
      dataView.statusText.isHidden = true
      dataView.statusButton.image = nil
      dataView.statusButton.action = nil
      updateStatusImage(item: sideBarItem, cell: dataView)
      if sideBarItem is LocalBranchSidebarItem {
        configureLocalBranchItem(sideBarItem: sideBarItem, dataView: dataView)
      }
      pullRequestManager.updatePullRequestButton(item: sideBarItem,
                                                 view: dataView)
      dataView.buttonContainer.isHidden = dataView.statusButton.image == nil
      if sideBarItem.editable {
        textField.target = viewController
        textField.action = #selector(SidebarController.sidebarItemRenamed(_:))
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
  
  func cell(forItem item: SidebarItem) -> SidebarTableCellView?
  {
    let row = outline.row(forItem: item)
    guard row != -1
    else { return nil }
    
    return outline.view(atColumn: 0, row: row, makeIfNecessary: false)
           as? SidebarTableCellView
  }
    
  func updateStatusImage(item: SidebarItem, cell: SidebarTableCellView?)
  {
    guard let cell = cell ?? self.cell(forItem: item)
    else { return }
    
    if let image = buildStatusController.statusImage(for: item),
       let button = cell.statusButton {
      button.image = image
      if let localBranchItem = item as? LocalBranchSidebarItem,
         let localBranch = localBranchItem.branchObject() as? LocalBranch,
         let trackedName = localBranch.trackingBranchName {
        button.toolTip = trackedName
      }
      else {
        button.toolTip = ""
      }
      button.target = viewController
      button.action = #selector(SidebarController.showItemStatus(_:))
      button.isEnabled = true
    }
    
    cell.buttonContainer.isHidden = cell.statusButton.image == nil
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
      switch repository.trackingBranchStatus(for: sideBarItem.title) {
        case .none:
          break
        case .missing(let tracking):
          dataView.statusButton.image = NSImage(named: .xtTracking)
          dataView.statusButton.toolTip = tracking + " (missing)"
          dataView.statusButton.target = viewController
          dataView.statusButton.action =
              #selector(SidebarController.missingTrackingBranch(_:))
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
    let unmodifiedCounter: (FileChange) -> Bool = { $0.status != .unmodified }
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
              imageName: NSImage.rightFacingTriangleTemplateName,
              toolTip: .trackingToolTip)
      
      return rowView
    }
    else {
      return nil
    }
  }
}

extension SideBarDataSource: BuildStatusDisplay
{
  func updateStatusImage(item: SidebarItem)
  {
    updateStatusImage(item: item, cell: nil)
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
