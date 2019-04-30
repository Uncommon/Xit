import Cocoa

class PullOpController: FetchOpController
{
  override func start() throws
  {
    defer {
      windowController?.operationEnded(self)
    }
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
      NSLog("Can't pull - no tracking branch")
      throw RepoError.unexpected
    }
    
    tryRepoOperation {
      let options = XTRepository.FetchOptions(downloadTags: true,
                                              pruneBranches: true,
                                              passwordBlock: self.getPassword,
                                              progressBlock: self.shouldStop)
      
      try repository.pull(branch: branch, remote: remote, options: options)
      NotificationCenter.default.post(name: .XTRepositoryRefsChanged,
                                      object: repository)
      self.ended()
    }
  }
}
