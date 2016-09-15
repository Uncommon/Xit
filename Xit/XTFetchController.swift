import Cocoa


/// Runs a `fetch` operation.
class XTFetchController: XTPasswordOpController {
  
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
    
    let remotes = repository.remoteNames
    
    switch remotes.count {
      case 0:
        return nil
      case 1:
        return remotes[0]
      default:
        for remote in remotes {
          if remote == "origin" {
            return remote
          }
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
  func shouldStop(progress: git_transfer_progress) -> Bool
  {
    guard let repository = repository
    else { return true }
    
    if canceled {
      return true
    }
    
    let progressValue =
        progress.received_objects == progress.total_objects
            ? -1.0
            : Float(progress.total_objects) /
              Float(progress.received_objects)
    
    XTStatusView.update(status: "Fetching",
                        progress: progressValue,
                        repository: repository)
    return false
  }
  
  func executeFetch(remoteName: String,
                    downloadTags: Bool,
                    pruneBranches: Bool)
  {
    guard let repository = repository,
          let remote = try? repository.remote(remoteName)
    else { return }
    
    XTStatusView.update(
        status: "Fetching...", progress: 0.0, repository: repository)
    
    let repo = repository  // For use in the block without being tied to self
    
    tryRepoOperation(successStatus: "Fetch complete",
                     failureStatus: "Fetch failed") {
      try repo.fetch(remote: remote,
                     downloadTags: downloadTags,
                     pruneBranches: pruneBranches,
                     passwordBlock: self.getPassword,
                     progressBlock: self.shouldStop)
      NotificationCenter.default.post(
          name: NSNotification.Name.XTRepositoryRefsChanged, object: repository)
      self.ended()
    }
  }
}

