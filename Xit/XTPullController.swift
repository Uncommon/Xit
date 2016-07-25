import Cocoa

class XTPullController: XTFetchController {

  override func start() {
    do {
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
    
      let options = [
          GTRepositoryRemoteOptionsCredentialProvider: credentialProvider()]
    
      try repository.pullBranch(branch, remote: remote, options: options) {
        (progress: git_transfer_progress) -> Bool in
        // update status display
        return false
      }
    }
    catch {
      
    }
  }

  override func fetchCompleted()
  {
    do {
      guard let localBranch = try? repository.gtRepo.currentBranch(),
            let remoteBranch = localBranch.trackingBranchWithError(nil,
                                                                   success: nil)
      else { return }
      
      try repository.gtRepo.mergeBranchIntoCurrentBranch(remoteBranch)
      XTStatusView.update(
          status: "Pull complete", progress: -1, repository: repository)
    }
    catch let error as NSError {
      XTStatusView.update(status: "Pull failed",
                          progress: -1,
                          repository: repository)
      dispatch_sync(dispatch_get_main_queue()) {
        if let window = self.windowController?.window {
          NSAlert(error: error).beginSheetModalForWindow(
              window, completionHandler: nil)
        }
      }
    }
  }

}
