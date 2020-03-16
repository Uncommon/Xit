import Foundation

/// Stores a repo reference for C callbacks
struct CallbackPayload { let repo: XTRepository }

let kEmptyTreeHash = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
let XTPathsKey = "paths"

public class XTRepository: NSObject, BasicRepository, RepoConfiguring
{
  let gitRepo: OpaquePointer
  @objc public let repoURL: URL
  let gitRunner: CLIRunner
  let mutex = Mutex()
  var refsIndex = [String: [String]]()
  
  public var controller: RepositoryController? = nil
  
  fileprivate(set) public var isWriting = false

  fileprivate(set) var cachedHeadRef, cachedHeadSHA, cachedBranch: String?
  private var _cachedBranches: [String: GitBranch] = [:]
  var cachedStagedChanges: [FileChange]?
  {
    get { controller?.cachedStagedChanges }
    set { controller?.cachedStagedChanges = newValue }
  }
  var cachedAmendChanges: [FileChange]?
  {
    get { controller?.cachedAmendChanges }
    set { controller?.cachedAmendChanges = newValue }
  }
  var cachedUnstagedChanges: [FileChange]?
  {
    get { controller?.cachedUnstagedChanges }
    set { controller?.cachedUnstagedChanges = newValue }
  }
  var cachedBranches: [String: GitBranch]
  {
    get { return mutex.withLock { _cachedBranches } }
    set { mutex.withLock { _cachedBranches = newValue } }
  }
  var cachedIgnored = false

  let diffCache = Cache<String, Diff>(maxSize: 50)
  public let config: Config
  
  var gitDirectoryPath: String
  {
    guard let path = git_repository_path(gitRepo)
    else { return "" }
    
    return String(cString: path)
  }
  
  static func gitPath() -> String?
  {
    let paths = ["/usr/bin/git", "/usr/local/git/bin/git"]
    
    return paths.first { FileManager.default.fileExists(atPath: $0) }
  }
  
  static func taskQueueID(path: String) -> String
  {
    let identifier = Bundle.main.bundleIdentifier ?? "com.uncommonplace.xit"
    
    return "\(identifier).\(path)"
  }
  
  init?(gitRepo: OpaquePointer)
  {
    guard let gitCmd = XTRepository.gitPath(),
          let workDirPath = git_repository_workdir(gitRepo),
          let config = GitConfig(repository: gitRepo)
    else { return nil }
    let url = URL(fileURLWithPath: String(cString: workDirPath))

    self.gitRepo = gitRepo
    self.repoURL = url
    self.gitRunner = CLIRunner(toolPath: gitCmd,
                               workingDir: url.path)
    self.config = config
    
    super.init()
}
  
  @objc(initWithURL:)
  convenience init?(url: URL)
  {
    guard url.isFileURL
    else { return nil }
    var repo: OpaquePointer? = nil
    let path = (url.path as NSString).fileSystemRepresentation
    let result = git_repository_open(&repo, path)
    guard result == 0,
          let finalRepo = repo
    else { return nil }
    
    self.init(gitRepo: finalRepo)
  }
  
  convenience init?(emptyURL url: URL)
  {
    var repo: OpaquePointer? = nil
    let path = (url.path as NSString).fileSystemRepresentation
    let result = git_repository_init(&repo, path, 0)
    guard result == 0,
          let finalRepo = repo
    else { return nil }
    
    self.init(gitRepo: finalRepo)
  }
  
  deinit
  {
    NotificationCenter.default.removeObserver(self)
  }
  
  func addCachedBranch(_ branch: GitBranch)
  {
    mutex.withLock {
      _cachedBranches[branch.name] = branch
    }
  }
  
  func updateIsWriting(_ writing: Bool)
  {
    guard writing != isWriting
    else { return }
    
    mutex.withLock {
      isWriting = writing
    }
  }
    
  func clearCachedBranch()
  {
    mutex.withLock {
      cachedBranch = nil
    }
  }
  
  func refsChanged()
  {
    cachedBranches = [:]
    
    // In theory the two separate locks could result in cachedBranch being wrong
    // but that would only happen if this function was called on two different
    // threads and one of them found that the branch had just changed again.
    // Not likely.
    guard let newBranch = calculateCurrentBranch(),
          mutex.withLock({ newBranch != cachedBranch })
    else { return }
    
    changingValue(forKey: #keyPath(currentBranch)) {
      mutex.withLock {
        cachedBranch = newBranch
      }
    }
  }
  
  func recalculateHead()
  {
    guard let headReference = self.headReference
    else { return }
    
    switch headReference.type {
      case .symbolic:
        cachedHeadRef = headReference.symbolicTargetName
      case .direct:
        cachedHeadRef = headReference.name
      default:
        break
    }
    cachedHeadSHA = sha(forRef: headReference.name)
  }
  
  func invalidateIndex()
  {
    controller?.invalidateIndex()
  }
  
  func writing(_ block: () -> Bool) -> Bool
  {
    objc_sync_enter(self)
    defer {
      objc_sync_exit(self)
    }
    
    guard !isWriting
    else { return false }
    
    isWriting = true
    defer {
      isWriting = false
    }
    return block()
  }
  
  func executeGit(args: [String],
                  stdIn: String?,
                  writes: Bool) throws -> Data
  {
    return try executeGit(args: args,
                          stdInData: stdIn?.data(using: .utf8),
                          writes: writes)
  }
  
  func executeGit(args: [String],
                  stdInData: Data? = nil,
                  writes: Bool) throws -> Data
  {
    guard FileManager.default.fileExists(atPath: repoURL.path)
    else {
      throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError,
                    userInfo: nil)
    }
    
    objc_sync_enter(self)
    defer {
      objc_sync_exit(self)
    }
    if writes && isWriting {
      throw RepoError.alreadyWriting
    }
    
    let wasWriting = isWriting
    
    updateIsWriting(writes)
    defer {
      updateIsWriting(wasWriting)
    }
    
    return try gitRunner.run(inputData: stdInData, args: args)
  }
}

// For testing
internal func setRepoWriting(_ repo: XTRepository, _ writing: Bool)
{
  repo.isWriting = writing
}

extension XTRepository: WritingManagement
{
  public func performWriting(_ block: (() throws -> Void)) throws
  {
    try mutex.withLock {
      if isWriting {
        throw RepoError.alreadyWriting
      }
      isWriting = true
    }
    defer {
      updateIsWriting(false)
    }
    try block()
  }
}

extension XTRepository
{
  /// Returns the unstaged and staged status of the given file.
  func status(file: String) throws -> (DeltaStatus, DeltaStatus)
  {
    var statusFlags: UInt32 = 0
    let result = git_status_file(&statusFlags, gitRepo, file)
    
    try RepoError.throwIfGitError(result)
    
    let flags = git_status_t(statusFlags)
    var unstagedChange = DeltaStatus.unmodified
    var stagedChange = DeltaStatus.unmodified
    
    switch flags {
      case _ where flags.test(GIT_STATUS_WT_NEW):
        unstagedChange = .untracked
      case _ where flags.test(GIT_STATUS_WT_MODIFIED),
           _ where flags.test(GIT_STATUS_WT_TYPECHANGE):
        unstagedChange = .modified
      case _ where flags.test(GIT_STATUS_WT_DELETED):
        unstagedChange = .deleted
      case _ where flags.test(GIT_STATUS_WT_RENAMED):
        unstagedChange = .renamed
      case _ where flags.test(GIT_STATUS_IGNORED):
        unstagedChange = .ignored
      case _ where flags.test(GIT_STATUS_CONFLICTED):
        unstagedChange = .conflict
      // ignoring GIT_STATUS_WT_UNREADABLE
      default:
        break
    }
    
    switch flags {
      case _ where flags.test(GIT_STATUS_INDEX_NEW):
        stagedChange = .added
      case _ where flags.test(GIT_STATUS_INDEX_MODIFIED),
           _ where flags.test(GIT_STATUS_WT_TYPECHANGE):
        stagedChange = .modified
      case _ where flags.test(GIT_STATUS_INDEX_DELETED):
        stagedChange = .deleted
      case _ where flags.test(GIT_STATUS_INDEX_RENAMED):
        stagedChange = .renamed
      default:
        break
    }
    
    return (unstagedChange, stagedChange)
  }
  
  func graphBetween(local: OID, upstream: OID) -> (ahead: Int,
                                                   behind: Int)?
  {
    guard let local = local as? GitOID,
          let upstream = upstream as? GitOID
    else { return nil }
    var ahead = 0
    var behind = 0
    
    if git_graph_ahead_behind(&ahead, &behind, gitRepo,
                              local.unsafeOID(), upstream.unsafeOID()) == 0 {
      return (ahead, behind)
    }
    else {
      return nil
    }
  }
  
  public func graphBetween(localBranch: LocalBranch,
                           upstreamBranch: RemoteBranch) ->(ahead: Int,
                                                            behind: Int)?
  {
    if let localOID = localBranch.oid,
       let upstreamOID = upstreamBranch.oid {
      return graphBetween(local: localOID, upstream: upstreamOID)
    }
    else {
      return nil
    }
  }
}
