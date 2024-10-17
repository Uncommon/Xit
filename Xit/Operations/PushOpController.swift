import Cocoa

final class PushOpController: PasswordOpController
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

  nonisolated
  func progressCallback(progress: PushTransferProgress) -> Bool
  {
    guard !canceled
    else { return false }

    Task {
      @MainActor in
      windowController?.repoController.post(
          progress: Float(progress.current),
          total: Float(progress.total))
    }
    return true
  }

  override func start() throws
  {
    guard let repository = repository
    else { throw RepoError.unexpected }

    try start(repository)
  }

  func start<R>(_ repository: R) throws where R: FullRepository
  {
    let remote: R.Remote
    let branches: [LocalBranchRefName]

    switch remoteOption {
      case .all:
        throw RepoError.unexpected

      case .new:
        try pushNewBranch(repository)
        return
      
      case .currentBranch, nil:
        guard let branchName = repository.currentBranch,
              let currentBranch = repository.localBranch(named: branchName)
        else {
          repoLogger.debug("Can't get current branch")
          throw RepoError.detachedHead
        }
        guard let remoteBranch = currentBranch.trackingBranch,
              let remoteName = remoteBranch.remoteName,
              let trackedRemote = repository.remote(named: remoteName)
        else {
          try pushNewBranch(repository)
          return
        }

        remote = trackedRemote
        branches = [branchName]

      case .named(let remoteName):
        guard let namedRemote = repository.remote(named: remoteName)
        else { throw RepoError.notFound }
        let localTrackingBranches = repository.localBranches.filter {
          $0.trackingBranch?.remoteName == remoteName
        }
        guard !localTrackingBranches.isEmpty
        else {
          let alert = NSAlert()
          
          alert.messageString = .noRemoteBranches(remoteName)
          alert.beginSheetModal(for: windowController!.window!)
          return
        }

        remote = namedRemote
        branches = localTrackingBranches.map { $0.referenceName }
    }

    let alert = NSAlert()
    let remoteName = remote.name ?? "origin"
    let message: UIString = branches.count == 1 ?
          .confirmPush(localBranch: branches.first!.fullPath,
                       remote: remoteName) :
          .confirmPushAll(remote: remoteName)
    
    alert.messageString = message
    alert.addButton(withString: .push)
    alert.addButton(withString: .cancel)
    
    alert.beginSheetModal(for: windowController!.window!) {
      (response) in
      if response == .alertFirstButtonReturn {
        self.push(repository, branches: branches, remote: remote)
      }
      else {
        self.ended(result: .canceled)
      }
    }
  }

  func pushNewBranch(_ repository: some RemoteManagement &
                     CommitReferencing & Branching) throws
  {
    guard let window = windowController?.window,
          let branchName = repository.currentBranch,
          let currentBranch = repository.localBranch(named: branchName)
    else {
      throw RepoError.unexpected
    }
    let sheetController = PushNewPanelController.controller()
  
    sheetController.alreadyTracking = currentBranch.trackingBranchName != nil
    sheetController.setRemotes(repository.remoteNames())
    
    window.beginSheet(sheetController.window!) {
      (response) in
      guard response == .OK
      else {
        self.ended(result: .canceled)
        return
      }
      guard let remote = repository.remote(named: sheetController.selectedRemote)
      else {
        self.ended(result: .failure)
        return
      }
      
      self.push(repository, branches: [branchName], remote: remote, then: {
        // This is now on the repo queue
        if let remoteName = remote.name {
          DispatchQueue.main.async {
            if sheetController.setTrackingBranch {
              currentBranch.trackingBranchName =
                  remoteName +/
                  currentBranch.referenceName.localName
            }
          }
        }
      })
    }
  }
  
  override func shoudReport(error: NSError) -> Bool
  {
    return true
  }
  
  override func repoErrorMessage(for error: RepoError) -> UIString
  {
    if error.isGitError(GIT_EBAREREPO) {
      return .pushToBare
    }
    else {
      return super.repoErrorMessage(for: error)
    }
  }
  
  func push<R>(_ repository: R,
               branches: [LocalBranchRefName],
               remote: R.Remote,
               then callback: (@Sendable () -> Void)? = nil)
    where R: RemoteManagement
  {
    if let url = remote.pushURL ?? remote.url {
      self.setKeychainInfo(from: url)
    }

    tryRepoOperation {
      let callbacks = RemoteCallbacks(passwordBlock: self.getPassword,
                                      downloadProgress: nil,
                                      uploadProgress: self.progressCallback)

      try repository.push(branches: branches,
                          remote: remote,
                          callbacks: callbacks)
      callback?()
      self.refsChangedAndEnded()
    }
  }
}
