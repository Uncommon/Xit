import Cocoa

final class PullOpController: FetchOpController
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
      repoLogger.debug("Can't get current branch")
      throw RepoError.detachedHead
    }
    guard let remoteBranch = branch.trackingBranch,
          let remoteName = remoteBranch.remoteName,
          let remote = repository.remote(named: remoteName)
    else {
      repoLogger.debug("Can't pull - no tracking branch")
      throw RepoError.unexpected
    }
    
    tryRepoOperation {
      let callbacks = RemoteCallbacks(passwordBlock: self.getPassword,
                                      downloadProgress: self.progressCallback,
                                      uploadProgress: nil)
      let options = FetchOptions(downloadTags: true,
                                 pruneBranches: true,
                                 callbacks: callbacks)
      
      try repository.pull(branch: branch, remote: remote, options: options)
      self.windowController?.repoController.refsChanged()
      self.ended()
    }
  }
}
