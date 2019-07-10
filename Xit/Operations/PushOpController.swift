import Cocoa

class PushOpController: PasswordOpController
{
  func shouldStop(progress: PushTransferProgress) -> Bool
  {
    guard !canceled,
          let repository = repository
    else { return true }
    
    let note = Notification.progressNotification(repository: repository,
                                                 progress: Float(progress.current),
                                                 total: Float(progress.total))
    
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
      throw RepoError.detachedHead
    }
    guard let remoteBranch = branch.trackingBranch,
          let remoteName = remoteBranch.remoteName,
          let remote = repository.remote(named: remoteName)
    else {
      NSLog("Can't push - no tracking branch")
      throw RepoError.unexpected
    }
    
    let alert = NSAlert()
    
    alert.messageString = .confirmPush(localBranch: branchName,
                                       remote: remoteName)
    alert.addButton(withString: .push)
    alert.addButton(withString: .cancel)
    
    alert.beginSheetModal(for: windowController!.window!) {
      (response) in
      if response == .alertFirstButtonReturn {
        self.push(localBranch: branch, remote: remote)
      }
      else {
        self.ended(result: .canceled)
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
    tryRepoOperation {
      guard let repository = self.repository
      else { return }
      let callbacks = RemoteCallbacks(passwordBlock: self.getPassword,
                                      downloadProgress: nil,
                                      uploadProgress: self.shouldStop)
      
      if let url = remote.pushURL ?? remote.url {
        self.setKeychainInfoURL(url)
      }

      try repository.push(branch: localBranch,
                          remote: remote,
                          callbacks: callbacks)
      NotificationCenter.default.post(name: .XTRepositoryRefsChanged,
                                      object: repository)
      self.ended()
    }
  }
}
