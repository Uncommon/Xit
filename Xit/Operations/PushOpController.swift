import Cocoa

class PushOpController: PasswordOpController
{
  func shouldStop(current: UInt32, total: UInt32, bytes: size_t) -> Bool
  {
    guard !canceled,
          let repository = repository
    else { return true }
    
    let note = Notification.progressNotification(repository: repository,
                                                 progress: Float(current),
                                                 total: Float(total))
    
    NotificationCenter.default.post(note)
    return canceled
  }

  override func start() throws
  {
    guard let repository = repository,
          let branchName = repository.currentBranch,
          let branch = repository.localBranch(named: branchName)
    else {
      NSLog("Can't get current branch")
      throw XTRepository.Error.detachedHead
    }
    guard let remoteBranch = branch.trackingBranch,
          let remoteName = remoteBranch.remoteName,
          let remote = repository.remote(named: remoteName)
    else {
      NSLog("Can't push - no tracking branch")
      throw XTRepository.Error.unexpected
    }
    
    let alert = NSAlert()
    
    alert.messageText = "Push local branch \"\(branchName)\" to " +
                        "remote \"\(remoteName)\"?"
    alert.addButton(withTitle: "Push")
    alert.addButton(withTitle: "Cancel")
    
    alert.beginSheetModal(for: windowController!.window!) {
      (response) in
      if response == .alertFirstButtonReturn {
        self.push(localBranch: branch, remote: remote)
      }
      else {
        self.ended()
      }
    }
  }
  
  override func shoudReport(error: NSError) -> Bool
  {
    if error.domain == GTGitErrorDomain && error.code == GIT_ERROR.rawValue {
      // Credentials not provided - user canceled
      return false
    }
    else {
      return true
    }
  }
  
  func push(localBranch: LocalBranch, remote: Remote)
  {
    tryRepoOperation(successStatus: "Push complete",
                     failureStatus: "Push failed") {
      guard let repository = self.repository
      else { return }
      
      try repository.push(branch: localBranch,
                          remote: remote,
                          passwordBlock: self.getPassword,
                          progressBlock: self.shouldStop)
      NotificationCenter.default.post(name: .XTRepositoryRefsChanged,
                                      object: repository)
      self.ended()
    }
  }
}
