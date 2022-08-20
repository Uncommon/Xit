import Cocoa

final class PushOpController: PasswordOpController
{
  let remoteOption: RemoteOperationOption?
  private var progressor: Progressor!

  override var canceled: Bool
  {
    didSet
    {
      progressor.canceled = canceled
    }
  }

  /// A nonisolated space for the progress callback
  private final class Progressor
  {
    var canceled: Bool
    {
      get { mutex.withLock { canceledPrivate } }
      set { mutex.withLock { canceledPrivate = newValue} }
    }
    weak var repository: FullRepository?

    private var canceledPrivate = false
    private var mutex: Mutex = .init()

    init(repository: FullRepository?)
    {
      self.repository = repository
    }

    func progressCallback(progress: PushTransferProgress) -> Bool
    {
      guard !canceled,
            let repository = repository
      else { return true }

      let note = Notification.progressNotification(
            repository: repository,
            progress: Float(progress.current),
            total: Float(progress.total))

      NotificationCenter.default.post(note)
      return !canceled
    }
  }

  init(remoteOption: RemoteOperationOption, windowController: XTWindowController)
  {
    self.remoteOption = remoteOption

    super.init(windowController: windowController)

    self.progressor = .init(repository: repository)
  }

  required init(windowController: XTWindowController)
  {
    self.remoteOption = nil

    super.init(windowController: windowController)
  }


  override func start() throws
  {
    guard let repository = repository
    else { throw RepoError.unexpected }

    let remote: any Remote
    let branches: [any LocalBranch]

    switch remoteOption {
      case .all:
        throw RepoError.unexpected

      case .new:
        try pushNewBranch()
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
          try pushNewBranch()
          return
        }

        remote = trackedRemote
        branches = [currentBranch]

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
        branches = localTrackingBranches
    }

    let alert = NSAlert()
    let remoteName = remote.name ?? "origin"
    let message: UIString = branches.count == 1 ?
          .confirmPush(localBranch: branches.first!.name, remote: remoteName) :
          .confirmPushAll(remote: remoteName)
    
    alert.messageString = message
    alert.addButton(withString: .push)
    alert.addButton(withString: .cancel)
    
    alert.beginSheetModal(for: windowController!.window!) {
      (response) in
      if response == .alertFirstButtonReturn {
        self.push(branches: branches, remote: remote)
      }
      else {
        self.ended(result: .canceled)
      }
    }
  }
  
  func pushNewBranch() throws
  {
    guard let repository = self.repository,
          let window = windowController?.window,
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
      
      self.push(branches: [currentBranch], remote: remote, then: {
        // This is now on the repo queue
        DispatchQueue.main.async {
          if sheetController.setTrackingBranch,
             let remoteName = remote.name {
            currentBranch.trackingBranchName = remoteName +/
                                               currentBranch.strippedName
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
  
  func push(branches: [any LocalBranch],
            remote: any Remote,
            then callback: (() -> Void)? = nil)
  {
    tryRepoOperation {
      guard let repository = self.repository
      else { return }
      let callbacks = RemoteCallbacks(
            passwordBlock: self.getPassword,
            downloadProgress: nil,
            uploadProgress: self.progressor.progressCallback)
      
      if let url = remote.pushURL ?? remote.url {
        self.setKeychainInfo(from: url)
      }

      try repository.push(branches: branches,
                          remote: remote,
                          callbacks: callbacks)
      callback?()
      self.windowController?.repoController.refsChanged()
      self.ended()
    }
  }
}
