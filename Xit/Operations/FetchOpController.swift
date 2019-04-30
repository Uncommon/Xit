import Cocoa


/// Runs a `fetch` operation.
class FetchOpController: PasswordOpController
{
  /// The default remote to fetch from, either:
  /// - the current branch's tracking branch
  /// - if there are multiple remotes, the one named "origin"
  /// - if there is one remote, use that one
  func defaultRemoteName() -> String?
  {
    guard let repository = repository
    else { return nil }
    
    if let branchName = repository.currentBranch {
      let currentBranch = repository.localBranch(named: branchName)
      
      if let trackingBranch = currentBranch?.trackingBranch {
        return trackingBranch.remoteName
      }
    }
    
    let remotes = repository.remoteNames()
    
    switch remotes.count {
      case 0:
        return nil
      case 1:
        return remotes[0]
      default:
        for remote in remotes where remote == "origin" {
          return remote
        }
        return remotes[0]
    }
  }
  
  override func start() throws
  {
    guard let repository = repository
    else { throw RepoError.unexpected }
    
    let config = repository.config
    let panel = FetchPanelController.controller()
    
    if let remoteName = defaultRemoteName() {
      panel.selectedRemote = remoteName
    }
    panel.parentController = windowController
    panel.downloadTags = config?.fetchTags(remote: panel.selectedRemote) ?? false
    panel.pruneBranches = config?.fetchPrune(remote: panel.selectedRemote) ?? false
    windowController!.window!.beginSheet(panel.window!) {
      (response) in
      if response == NSApplication.ModalResponse.OK {
        self.executeFetch(remoteName: panel.selectedRemote as String,
                          downloadTags: panel.downloadTags,
                          pruneBranches: panel.pruneBranches)
      }
      else {
        self.ended(result: .canceled)
      }
    }
  }
  
  /// Fetch progress callback
  func shouldStop(progress: TransferProgress) -> Bool
  {
    guard !canceled,
          let repository = repository
    else { return true }
    
    let received = Float(progress.receivedObjects)
    let indexed = Float(progress.indexedObjects)
    let note = Notification.progressNotification(
          repository: repository,
          progress: (received + indexed) / 2,
          total: Float(progress.totalObjects))
    
    NotificationCenter.default.post(note)
    return false
  }
  
  func executeFetch(remoteName: String,
                    downloadTags: Bool,
                    pruneBranches: Bool)
  {
    guard let repository = repository,
          let remote = repository.remote(named: remoteName)
    else { return }
    
    if let url = remote.url {
      setKeychainInfoURL(url)
    }
    
    let repo = repository  // For use in the block without being tied to self
    
    tryRepoOperation {
      let options = XTRepository.FetchOptions(downloadTags: downloadTags,
                                              pruneBranches: pruneBranches,
                                              passwordBlock: self.getPassword,
                                              progressBlock: self.shouldStop)
      
      try repo.fetch(remote: remote, options: options)
      NotificationCenter.default.post(name: .XTRepositoryRefsChanged,
                                      object: repository)
      self.ended()
    }
  }
}
