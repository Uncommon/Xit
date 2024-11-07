import Foundation
import Cocoa

extension SidebarController
{
  @IBAction
  func sidebarItemRenamed(_ sender: Any)
  {
    guard let textField = sender as? NSTextField,
          let cellView = textField.superview?.superview as? SidebarTableCellView,
          let editedItem = cellView.item
    else { return }
    
    let newName = textField.stringValue
    let oldName = editedItem.title
    guard newName != oldName
    else { return }
    
    if editedItem.refType == .remote {
      try? repo.renameRemote(old: oldName, new: newName)
    }
  }
  
  @IBAction
  func checkOutBranch(_ sender: Any?)
  {
    callCommand {
      [weak self] (item) in
      do {
        guard let branch = LocalBranchRefName.named(item.title)
        else { return }
        try self?.repo.checkOut(branch: branch)
      }
      catch let error as RepoError {
        switch error {
          case .conflict, .localConflict:
            DispatchQueue.main.async {
              guard let self = self
              else { return }
              let alert = NSAlert()
              
              alert.messageString = .checkoutFailedConflict
              alert.informativeString = .checkoutFailedConflictInfo
              alert.beginSheetModal(for: self.view.window!)
            }
          default:
            break
        }
      }
    }
  }
  
  @IBAction
  func createTrackingBranch(_ sender: Any?)
  {
    guard let item = targetItem() as? RemoteBranchSidebarItem,
          let controller = view.window?.windowController as? XTWindowController
    else { return }
    guard let refName = RemoteBranchRefName.named(item.fullName)
    else {
      assertionFailure("can't resolve item ref name")
      return
    }
    
    controller.startOperation {
      CheckOutRemoteOpController(windowController: controller,
                                 branch: refName)
    }
  }
  
  @IBAction
  func renameBranch(_ sender: Any?)
  {
    guard let selectedItem = targetItem(),
          let controller = view.window?.windowController as? XTWindowController,
          let branchName = LocalBranchRefName.named(selectedItem.title)
    else { return }
    
    controller.startRenameBranch(branchName)
  }
  
  @IBAction
  func mergeBranch(_ sender: Any?)
  {
    guard let selectedItem = targetItem() as? BranchSidebarItem,
          let branch = selectedItem.branchObject(),
          let repo = self.repo,
          let queue = repoController?.queue
    else { return }
    let showAlert = { // capture self here instead of not-main-thread block
      [weak self] (repoError: RepoError) -> Void in
      guard let window = self?.view.window
      else { return }
      let alert = NSAlert()

      alert.messageString = repoError.message
      alert.beginSheetModal(for: window)
    }

    queue.executeOffMainThread {
      do {
        try repo.merge(branch: branch)
      }
      catch let repoError as RepoError {
        DispatchQueue.main.async {
          showAlert(repoError)
        }
      }
      catch {
        repoLogger.debug("Unexpected error")
      }
    }
  }
  
  @objc(deleteBranch:)
  @IBAction
  func deleteBranch(_ sender: Any?)
  {
    guard let item = targetItem()
    else { return }
    
    deleteBranch(item: item)
  }
  
  @IBAction
  func deleteTag(_ sender: Any?)
  {
    guard let item = targetItem()
    else { return }

    Task {
      if await confirmDelete(kind: "tag", name: item.title) {
        self.callCommand(targetItem: item) {
          [weak self] (item) in
          guard let tag = TagRefName.named(item.title)
          else { return }
          try self?.repo.deleteTag(name: tag)
        }
      }
    }
  }
  
  @IBAction
  func renameRemote(_ sender: Any?)
  {
    editSelectedRow()
  }
  
  @IBAction
  func editRemote(_ sender: AnyObject)
  {
    guard let remoteItem = targetItem() as? RemoteSidebarItem,
          let controller = window?.windowController as? XTWindowController
    else { return }
    
    controller.remoteSettings(remote: remoteItem.title)
  }
  
  @IBAction
  func deleteRemote(_ sender: Any?)
  {
    callCommand {
      [weak self] (item) in
      try self?.repo.deleteRemote(named: item.title)
    }
  }
  
  @IBAction
  func copyRemoteURL(_ sender: Any?)
  {
    guard let item = targetItem()
    else { return }
    let remoteName = "remote.\(item.title).url"
    guard let remoteURL = repo.config.urlString(remote: remoteName)
    else { return }
    let pasteboard = NSPasteboard.general
    
    pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
    pasteboard.setString(remoteURL, forType: NSPasteboard.PasteboardType.string)
  }
  
  @IBAction
  func popStash(_ sender: Any?)
  {
    popStash()
  }
  
  @IBAction
  func applyStash(_ sender: Any?)
  {
    applyStash()
  }
  
  @IBAction
  func dropStash(_ sender: Any?)
  {
    NSAlert.confirm(message: .confirmStashDrop,
                    actionName: .drop,
                    isDestructive: true,
                    parentWindow: view.window!) {
      self.dropStash()
    }
  }
  
  @IBAction
  func showSubmodule(_ sender: Any?)
  {
    guard let submoduleItem = targetItem() as? SubmoduleSidebarItem
    else { return }
    let url = repo.fileURL(submoduleItem.submodule.path)
    
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
  
  @IBAction
  func updateSubmodule(_ sender: Any?)
  {
    
  }
  
  @IBAction
  func pullRequestClicked(_ sender: Any?)
  {
    
  }

  @IBAction
  func showItemStatus(_ sender: NSButton)
  {
    guard let item = SidebarTableCellView.item(for: sender) as? BranchSidebarItem,
          let branch = item.branchObject()
    else { return }
    
    let statusController = BuildStatusViewController(
          repository: repo,
          branch: branch,
          cache: buildStatusController.buildStatusCache)
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
    guard let item = SidebarTableCellView.item(for: sender)
                     as? LocalBranchSidebarItem
    else { return }
    
    let alert = NSAlert()
    
    alert.alertStyle = .informational
    alert.messageString = .trackingBranchMissing
    alert.informativeString = .trackingMissingInfo(item.title)
    alert.addButton(withString: .clear)
    alert.addButton(withString: .deleteBranch)
    alert.addButton(withString: .cancel)
    alert.beginSheetModal(for: window!) {
      (response) in
      switch response {
        
        case .alertFirstButtonReturn: // Clear
          if let refName = LocalBranchRefName.named(item.title),
             let branch = self.repo.localBranch(named: refName) {
            branch.trackingBranchName = nil
          }
          self.sidebarOutline.reloadItem(item)
        
        case .alertSecondButtonReturn: // Delete
          self.deleteBranch(item: item)
        
        default:
          break
      }
    }
  }
  
  @IBAction
  func doubleClick(_: Any?)
  {
    if let outline = sidebarOutline,
       let clickedItem = outline.item(atRow: outline.clickedRow)
                         as? SubmoduleSidebarItem,
       let rootPath = repo?.repoURL.path {
      let subURL = URL(fileURLWithPath: rootPath +/ clickedItem.submodule.path)
      
      NSDocumentController.shared.openDocument(
      withContentsOf: subURL, display: true) { (_, _, _) in }
    }
  }
}
