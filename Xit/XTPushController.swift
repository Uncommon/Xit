import Cocoa

class XTPushController: XTPasswordOpController {
  
  func shouldStop(current: UInt32, total: UInt32, bytes: size_t) -> Bool
  {
    XTStatusView.update(status: "Pushing...",
                        progress: Float(total)/Float(current),
                        repository: repository)
    return canceled
  }

  override func start()
  {
    guard let branchName = repository.currentBranch,
          let branch = XTLocalBranch(repository: repository,
                                     name: branchName)
      else {
        NSLog("Can't get current branch")
        return
    }
    guard let remoteBranch = branch.trackingBranch,
          let remote = XTRemote(name: remoteBranch.remoteName,
                                repository: repository)
      else {
        NSLog("Can't push - no tracking branch")
        return
    }
    
    let alert = NSAlert()
    
    alert.messageText = "Push local branch \(branchName) to " +
                        "remote \"\(remoteBranch.remoteName)\"?"
    alert.addButtonWithTitle("Push")
    alert.addButtonWithTitle("Cancel")
    
    alert.beginSheetModalForWindow(windowController!.window!) {
      (response) in
      if (response == NSAlertFirstButtonReturn) {
        self.push(branch, remote: remote)
      }
      else {
        self.ended()
      }
    }
  }
  
  func push(localBranch: XTLocalBranch, remote: XTRemote)
  {
    tryRepoOperation(successStatus: "Push complete",
                     failureStatus: "Push failed") {
      try self.repository.push(branch: localBranch,
                               remote: remote,
                               passwordBlock: self.getPassword,
                               progressBlock: self.shouldStop)
      self.ended()
    }
  }

}
