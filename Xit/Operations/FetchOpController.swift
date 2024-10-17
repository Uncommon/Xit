import Cocoa


/// Runs a `fetch` operation.
class FetchOpController: PasswordOpController
{
  let remoteOption: RemoteOperationOption?

  init(remoteOption: RemoteOperationOption, windowController: XTWindowController)
  {
    self.remoteOption = remoteOption

    super.init(windowController: windowController)
  }

  required init(windowController: XTWindowController)
  {
    self.remoteOption = nil

    super.init(windowController: windowController)
  }

  @MainActor
  override func start() throws
  {
    guard let repository = repository
    else { throw RepoError.unexpected }
    
    if let remoteOption = self.remoteOption {
      switch remoteOption {

        case .all:
          for remote in repository.remoteNames() {
            executeFetch(remoteName: remote)
          }

        case .currentBranch:
          guard let branchName = repository.currentBranch,
                let branch = repository.localBranch(named: branchName),
                let remote = branch.trackingBranch?.remoteName
          else { break }

          executeFetch(remoteName: remote)
        
        case .named(let remote):
          executeFetch(remoteName: remote)
          
        case .new:
          throw RepoError.unexpected
      }
    }
    else {
      Task {
        guard let options = await FetchDialog(repository: repository).getOptions(
            parent: windowController!.window!)
        else {
          self.ended(result: .canceled)
          return
        }

        self.executeFetch(remoteName: options.remote,
                          downloadTags: options.downloadTags,
                          pruneBranches: options.pruneBranches)
      }
    }
  }
  
  /// Fetch progress callback
  nonisolated
  func progressCallback(progress: TransferProgress) -> Bool
  {
    Task {
      @MainActor in
      guard !canceled
      else { return }

      let received = Float(progress.receivedObjects)
      let indexed = Float(progress.indexedObjects)
      
      windowController?.repoController.post(
        progress: (received + indexed) / 2,
        total: Float(progress.totalObjects))
    }
    return true
  }

  func executeFetch(remoteName: String)
  {
    let config = repository!.config

    executeFetch(remoteName: remoteName,
                 downloadTags: config.fetchTags(remote: remoteName),
                 pruneBranches: config.fetchPrune(remote: remoteName))
  }

  func executeFetch(remoteName: String,
                    downloadTags: Bool,
                    pruneBranches: Bool)
  {
    guard let repository = repository
    else { return }

    executeFetch(repository, remoteName: remoteName,
                 downloadTags: downloadTags, pruneBranches: pruneBranches)
  }

  func executeFetch(_ repository: some RemoteManagement,
                    remoteName: String,
                    downloadTags: Bool,
                    pruneBranches: Bool)
  {
    guard let remote = repository.remote(named: remoteName)
    else { return }
    
    if let url = remote.url {
      setKeychainInfo(from: url)
    }
    
    tryRepoOperation {
      let callbacks = RemoteCallbacks(passwordBlock: self.getPassword,
                                      downloadProgress: self.progressCallback,
                                      uploadProgress: nil)
      let options = FetchOptions(downloadTags: downloadTags,
                                 pruneBranches: pruneBranches,
                                 callbacks: callbacks)
      
      try repository.fetch(remote: remote, options: options)
      self.refsChangedAndEnded()
    }
  }
}
