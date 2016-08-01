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
        NSLog("Can't push - no tracking branch")
        return
    }
    
    repository.executeOffMainThread {
      do {
        try self.repository.push(branch: branch,
                                 remote: remote,
                                 passwordBlock: self.getPassword,
                                 progressBlock: self.shouldStop)
        XTStatusView.update(status: "Push complete",
                            progress: -1,
                            repository: self.repository)
      }
      catch let error as NSError {
        dispatch_async(dispatch_get_main_queue()) {
          XTStatusView.update(status: "Push failed",
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
