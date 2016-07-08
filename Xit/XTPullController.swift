import Cocoa

class XTPullController: XTFetchController {

  // start(): verify that the current branch has a tracking branch

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
      XTStatusView.update(
          status: "Pull failed", progress: -1, repository: repository)
      dispatch_sync(dispatch_get_main_queue()) {
        if let window = self.windowController?.window {
          NSAlert(error: error).beginSheetModalForWindow(
              window, completionHandler: nil)
        }
      }
    }
  }

}
