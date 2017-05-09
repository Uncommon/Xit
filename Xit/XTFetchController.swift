import Cocoa


/// Runs a `fetch` operation.
class XTFetchController: XTPasswordOpController
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
      let currentBranch = XTLocalBranch(repository: repository,
                                        name: branchName)
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
  
  override func start()
  {
    guard let repository = repository
    else { return }
    
    let config = XTConfig(repository: repository)
    let panel = XTFetchPanelController.controller()
    
    if let remoteName = defaultRemoteName() {
      panel.selectedRemote = remoteName
    }
    panel.parentController = windowController
    panel.downloadTags = config.fetchTags(panel.selectedRemote)
    panel.pruneBranches = config.fetchPrune(panel.selectedRemote)
    self.windowController!.window!.beginSheet(panel.window!) { (response) in
      if response == NSModalResponseOK {
        self.executeFetch(remoteName: panel.selectedRemote as String,
                          downloadTags: panel.downloadTags,
                          pruneBranches: panel.pruneBranches)
      }
      else {
        self.ended()
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
          let remote = XTRemote(name: remoteName, repository: repository)
    else { return }
    
    let repo = repository  // For use in the block without being tied to self
    
    tryRepoOperation(successStatus: "Fetch complete",
                     failureStatus: "Fetch failed") {
      let options = XTRepository.FetchOptions(downloadTags: downloadTags,
                                              pruneBranches: pruneBranches,
                                              passwordBlock: self.getPassword,
                                              progressBlock: self.shouldStop)
      
      try repo.fetch(remote: remote, options: options)
      NotificationCenter.default.post(
          name: NSNotification.Name.XTRepositoryRefsChanged, object: repository)
      self.ended()
    }
  }
}
