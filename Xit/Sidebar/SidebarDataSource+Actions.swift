import Foundation

extension SideBarDataSource
{
  func item(for button: NSButton) -> SidebarItem?
  {
    var superview = button.superview
    
    while superview != nil {
      if let cellView = superview as? SidebarTableCellView {
        return cellView.item
      }
      superview = superview?.superview
    }
    
    return nil
  }

  @IBAction
  func showItemStatus(_ sender: NSButton)
  {
    guard let item = item(for: sender) as? BranchSidebarItem,
      let branch = item.branchObject()
      else { return }
    
    let statusController = BuildStatusViewController(repository: repository,
                                                     branch: branch,
                                                     cache: buildStatusCache)
    let popover = NSPopover()
    
    statusPopover = popover
    popover.contentViewController = statusController
    popover.behavior = .transient
    popover.delegate = self
    popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
  }
  
  @IBAction
  func missingTrackingBranch(_ sender: NSButton)
  {
    guard let item = item(for: sender) as? LocalBranchSidebarItem
      else { return }
    
    let alert = NSAlert()
    
    alert.alertStyle = .informational
    alert.messageString = .trackingBranchMissing
    alert.informativeString = .trackingMissingInfo(item.title)
    alert.addButton(withString: .clear)
    alert.addButton(withString: .deleteBranch)
    alert.addButton(withString: .cancel)
    alert.beginSheetModal(for: outline.window!) {
      (response) in
      switch response {
        
      case .alertFirstButtonReturn: // Clear
        let branch = self.repository.localBranch(named: item.title)
        
        branch?.trackingBranchName = nil
        self.outline.reloadItem(item)
        
      case .alertSecondButtonReturn: // Delete
        self.viewController.deleteBranch(item: item)
        
      default:
        break
      }
    }
  }
  
  @objc func doubleClick(_: Any?)
  {
    if let outline = outline,
      let clickedItem = outline.item(atRow: outline.clickedRow)
        as? SubmoduleSidebarItem,
      let rootPath = repository?.repoURL.path {
      let subURL = URL(fileURLWithPath: rootPath.appending(
        pathComponent: clickedItem.submodule.path))
      
      NSDocumentController.shared.openDocument(
      withContentsOf: subURL, display: true) { (_, _, _) in }
    }
  }
}
