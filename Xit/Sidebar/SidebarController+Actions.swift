import Foundation
import Cocoa

extension SidebarController
{
  @IBAction func sidebarItemRenamed(_ sender: Any)
  {
    guard let textField = sender as? NSTextField,
          let cellView = textField.superview as? SidebarTableCellView,
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
  
  @IBAction func checkOutBranch(_ sender: Any?)
  {
    callCommand {
      [weak self] (item) in
      do {
        try self?.repo.checkOut(branch: item.title)
      }
      catch let error as NSError
            where error.domain == GTGitErrorDomain &&
                  error.gitError == GIT_ECONFLICT {
        DispatchQueue.main.async {
          guard let self = self
          else { return }
          let alert = NSAlert()
          
          alert.messageText =
              "Checkout failed because of a conflict with local changes."
          alert.informativeText =
              "Revert or stash your changes and try again."
          alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
        }
      }
    }
  }
  
  @IBAction func createTrackingBranch(_ sender: Any?)
  {
    guard let item = targetItem() as? RemoteBranchSidebarItem,
          let controller = view.window?.windowController as? XTWindowController
    else { return }
    
    controller.startOperation {
      CheckOutRemoteOperationController(windowController: controller,
                                        branch: item.fullName)
    }
  }
  
  @IBAction func renameBranch(_ sender: Any?)
  {
    guard let selectedItem = targetItem(),
          let controller = view.window?.windowController as? XTWindowController
    else { return }
    
    controller.startRenameBranch(selectedItem.title)
  }
  
  @IBAction func mergeBranch(_ sender: Any?)
  {
    guard let selectedItem = targetItem() as? BranchSidebarItem,
          let branch = selectedItem.branchObject()
    else { return }
    
    repo.queue.executeOffMainThread {
      [weak self] in
      do {
        try self?.repo.merge(branch: branch)
      }
      catch let repoError as XTRepository.Error {
        DispatchQueue.main.async {
          guard let window = self?.view.window
          else { return }
          let alert = NSAlert()
          
          alert.messageText = repoError.message
          alert.beginSheetModal(for: window, completionHandler: nil)
        }
      }
      catch {
        NSLog("Unexpected error")
      }
    }
  }
  
  @objc(deleteBranch:)
  @IBAction func deleteBranch(_ sender: Any?)
  {
    guard let item = targetItem()
    else { return }
    
    deleteBranch(item: item)
  }
  
  @IBAction func deleteTag(_ sender: Any?)
  {
    guard let item = targetItem()
    else { return }
    
    confirmDelete(kind: "tag", name: item.title) {
      self.callCommand(targetItem: item) {
        [weak self] (item) in
        try self?.repo.deleteTag(name: item.title)
      }
    }
  }
  
  @IBAction func renameRemote(_ sender: Any?)
  {
    editSelectedRow()
  }
  
  @IBAction func deleteRemote(_ sender: Any?)
  {
    callCommand {
      [weak self] (item) in
      try self?.repo.deleteRemote(named: item.title)
    }
  }
  
  @IBAction func copyRemoteURL(_ sender: Any?)
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
  
  @IBAction func popStash(_ sender: Any?)
  {
    popStash()
  }
  
  @IBAction func applyStash(_ sender: Any?)
  {
    applyStash()
  }
  
  @IBAction func dropStash(_ sender: Any?)
  {
    dropStash()
  }
  
  @IBAction func showSubmodule(_ sender: Any?)
  {
    guard let submoduleItem = targetItem() as? SubmoduleSidebarItem
    else { return }
    let url = repo.fileURL(submoduleItem.submodule.path)
    
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
  
  @IBAction func updateSubmodule(_ sender: Any?)
  {
    
  }
  
  @IBAction func pullRequestClicked(_ sender: Any?)
  {
    
  }
}
