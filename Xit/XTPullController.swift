import Cocoa

class XTPullController: XTFetchController {

  override func start() {
    defer {
      windowController?.operationEnded(self)
    }
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
      NSLog("Can't pull - no tracking branch")
      return
    }
    
    repository.executeOffMainThread {
      do {
        try self.repository.pull(branch: branch,
                                 remote: remote,
                                 downloadTags: true,
                                 pruneBranches: true,
                                 passwordBlock: self.getPassword,
                                 progressBlock: self.shouldStop)
      }
      catch _ as XTRepository.Error {
        // The command shouldn't have been enabled if this was going to happen
      }
      catch let error as NSError {
        dispatch_async(dispatch_get_main_queue()) {
          XTStatusView.update(status: "Pull failed",
                              progress: -1,
                              repository: self.repository)
          
          if let window = self.windowController?.window {
            let alert = NSAlert(error: error)
            
            // needs to be smarter: look at error type
            alert.beginSheetModalForWindow(window, completionHandler: nil)
          }
        }
      }
    }
  }

}
