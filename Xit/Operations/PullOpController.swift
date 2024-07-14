import Cocoa

final class PullOpController: FetchOpController
{
  override func start() throws
  {
    defer {
      windowController?.operationEnded(self)
    }
    guard let repository = repository,
          let branchName = repository.currentBranchRefName
    else {
      repoLogger.debug("Can't get current branch")
      throw RepoError.detachedHead
    }

    try start(repository, branchName)
  }

  func start(_ repository: some RemoteManagement & Branching,
             _ branchName: LocalBranchRefName) throws
  {
    guard let branch = repository.localBranch(named: branchName),
          let remoteBranch = branch.trackingBranch,
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
      self.refsChangedAndEnded()
    }
  }
}
