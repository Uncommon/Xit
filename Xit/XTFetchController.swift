import Cocoa


/// Runs a `fetch` operation.
class XTFetchController: XTOperationController {
  
  /// The default remote to fetch from, either:
  /// - the current branch's tracking branch
  /// - if there are multiple remotes, the one named "origin"
  /// - if there is one remote, use that one
  func defaultRemoteName() -> String?
  {
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
  
  func start()
  {
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
        self.executeFetch(panel.selectedRemote as String,
                          downloadTags: panel.downloadTags,
                          pruneBranches: panel.pruneBranches)
      }
      else {
        self.ended()
      }
    }
  }
  
  func ended()
  {
    self.windowController?.fetchEnded()
  }
  
  /// Fetch progress callback
  func shouldStop(progress progress: git_transfer_progress) -> Bool
  {
    if self.canceled {
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
  
  /// User/password callback
  func getPassword() -> (String, String)?
  {
    guard let window = self.windowController?.window
    else { return nil }
    
    let panel = XTPasswordPanelController.controller()
    let semaphore = dispatch_semaphore_create(0)
    var result: (String, String)? = nil
    
    dispatch_async(dispatch_get_main_queue()) {
      window.beginSheet(panel.window!) { (response) in
        if response == NSModalResponseOK {
          result = (panel.userName, panel.password)
        }
        _ = dispatch_semaphore_signal(semaphore)
      }
    }
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
    return result
  }
  
  func executeFetch(remoteName: String,
                    downloadTags: Bool,
                    pruneBranches: Bool)
  {
    guard let remote = try? repository.remote(remoteName)
    else { return }
    
    XTStatusView.update(
        status: "Fetching...", progress: 0.0, repository: repository)
    
    let repo = repository  // For use in the block without being tied to self
    
    repo.executeOffMainThread {
      do {
        try repo.fetch(remote: remote,
                       downloadTags: downloadTags,
                       pruneBranches: pruneBranches,
                       passwordBlock: self.getPassword,
                       progressBlock: self.shouldStop)
        self.fetchCompleted()
      }
      catch let error as NSError {
        dispatch_async(dispatch_get_main_queue()) {
          XTStatusView.update(status: "Fetch failed",
                              progress: -1,
                              repository: repo)
          
          if let window = self.windowController?.window {
            let alert = NSAlert(error: error)
            
            // needs to be smarter: look at error type
            alert.beginSheetModalForWindow(window, completionHandler: nil)
          }
        }
      }
      self.ended()
    }
  }
  
  /// The fetch phase is complete. This is factored out so pull can override it.
  func fetchCompleted()
  {
    XTStatusView.update(
        status: "Fetch complete", progress: -1, repository: repository)
  }
}

