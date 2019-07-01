import Cocoa

class SidebarDelegate: NSObject
{
  enum CellID
  {
    static let header = ¶"HeaderCell"
    static let data = ¶"DataCell"
  }
  
  @IBOutlet weak var controller: SidebarController?
  @IBOutlet weak var outline: NSOutlineView!
  weak var model: SidebarDataModel?
  var buildStatusController: BuildStatusController?
  var pullRequestManager: SidebarPRManager?
  
  func graphText(for item: SidebarItem) -> String?
  {
    guard let repository = model?.repository,
          item is LocalBranchSidebarItem,
          let localBranch = repository.localBranch(named: item.title),
          let trackingBranch = localBranch.trackingBranch,
          let graph = repository.graphBetween(localBranch: localBranch,
                                              upstreamBranch: trackingBranch)
    else { return nil }
    
    var numbers = [String]()
    
    if graph.ahead > 0 {
      numbers.append("↑\(graph.ahead)")
    }
    if graph.behind > 0 {
      numbers.append("↓\(graph.behind)")
    }
    return numbers.isEmpty ? nil : numbers.joined(separator: " ")
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
    
    if let image = buildStatusController?.statusImage(for: item) {
      cell.statusButton.image = image
      if let localBranchItem = item as? LocalBranchSidebarItem,
         let localBranch = localBranchItem.branchObject() as? LocalBranch,
         let tracked = localBranch.trackingBranchName {
        cell.statusButton.toolTip = tracked
      }
      cell.statusButton.target = controller
      cell.statusButton.action = #selector(SidebarController.showItemStatus(_:))
      cell.statusButton.isEnabled = true
    }
    cell.buttonContainer.isHidden = cell.statusButton.image == nil
  }
  
  fileprivate func configureLocalBranchItem(sideBarItem: SidebarItem,
                                            dataView: SidebarTableCellView)
  {
    guard let repository = model?.repository
    else { return }
    
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
          dataView.statusButton.target = controller
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
}

extension SidebarDelegate: NSOutlineViewDelegate
{
  public func outlineViewSelectionDidChange(_ notification: Notification)
  {
    guard let outline = notification.object as? NSOutlineView,
          let item = outline.item(atRow: outline.selectedRow)
                     as? SidebarItem,
          let selection = item.selection,
          let controller = outline.window?.windowController
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
    if (item as? SideBarGroupItem) === model?.rootItem(.workspace) {
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
    guard let sideBarItem = item as? SidebarItem
    else { return nil }
    
    if sideBarItem is SideBarGroupItem {
      guard let headerView = outlineView.makeView(withIdentifier: CellID.header,
                                                  owner: nil) as? NSTableCellView
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
      pullRequestManager?.updatePullRequestButton(item: sideBarItem,
                                                  view: dataView)
      dataView.buttonContainer.isHidden = dataView.statusButton.image == nil
      if sideBarItem.editable {
        textField.target = controller
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
  
  public func outlineView(_ outlineView: NSOutlineView,
                          rowViewForItem item: Any) -> NSTableRowView?
  {
    if let branchItem = item as? LocalBranchSidebarItem,
       branchItem.current {
      return SidebarCheckedRowView()
    }
    else if let remoteBranchItem = item as? RemoteBranchSidebarItem,
            let branchName = model!.repository?.currentBranch,
            let currentBranch = model!.repository?.localBranch(named: branchName),
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

extension SidebarDelegate: BuildStatusDisplay
{
  func updateStatusImage(item: SidebarItem)
  {
    updateStatusImage(item: item, cell: nil)
  }
}

extension SidebarDelegate: XTOutlineViewDelegate
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
      NotificationCenter.default.post(name: .XTReselectModel,
                                      object: model?.repository)
    }
    controller?.selectedItem = newSelectedItem
  }
}
