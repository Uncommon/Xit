import Foundation


extension NSNotification.Name
{
  /// Some change has been detected in the repository.
  static let XTRepositoryChanged =
      NSNotification.Name(rawValue: "XTRepositoryChanged")
  /// The repository's config file has changed.
  static let XTRepositoryConfigChanged =
      NSNotification.Name(rawValue: "XTRepositoryConfigChanged")
  /// The head reference (current branch) has changed.
  static let XTRepositoryHeadChanged =
      NSNotification.Name(rawValue: "XTRepositoryHeadChanged")
  /// The repository's index has changed.
  static let XTRepositoryIndexChanged =
      NSNotification.Name(rawValue: "XTRepositoryIndexChanged")
  /// The repository's refs have changed.
  static let XTRepositoryRefsChanged =
      NSNotification.Name(rawValue: "XTRepositoryRefsChanged")
  /// A file in the workspace has changed.
  static let XTRepositoryWorkspaceChanged =
      NSNotification.Name(rawValue: "XTRepositoryWorkspaceChanged")
  /// The stash log has changed.
  static let XTRepositoryStashChanged =
      NSNotification.Name(rawValue: "XTRepositoryStashChanged")
}


/// Stores a repo reference for C callbacks
struct CallbackPayload { let repo: XTRepository }

let kEmptyTreeHash = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
let XTPathsKey = "paths"
let XTErrorOutputKey = "output"
let XTErrorArgsKey = "args"

public class XTRepository: NSObject
{
  private(set) var gtRepo: GTRepository
  @objc public let repoURL: URL
  let gitCMD: String
  @objc let queue: TaskQueue
  let mutex = Mutex()
  var refsIndex = [String: [String]]()
  fileprivate(set) var isWriting = false
  fileprivate var executing = false
  
  fileprivate(set) var cachedHeadRef, cachedHeadSHA, cachedBranch: String?
  private var _cachedStagedChanges, _cachedAmendChanges,
              _cachedUnstagedChanges: [FileChange]?
  var cachedStagedChanges: [FileChange]?
  {
    get { return mutex.withLock { _cachedStagedChanges } }
    set { mutex.withLock { _cachedStagedChanges = newValue } }
  }
  var cachedAmendChanges: [FileChange]?
  {
    get { return mutex.withLock { _cachedAmendChanges } }
    set { mutex.withLock { _cachedAmendChanges = newValue } }
  }
  var cachedUnstagedChanges: [FileChange]?
  {
    get { return mutex.withLock { _cachedUnstagedChanges } }
    set { mutex.withLock { _cachedUnstagedChanges = newValue } }
  }

  let diffCache = Cache<String, Diff>(maxSize: 50)
  fileprivate var repoWatcher: XTRepositoryWatcher! = nil
  fileprivate var workspaceWatcher: WorkspaceWatcher! = nil
  private(set) var config: XTConfig! = nil
  
  var gitRepo: OpaquePointer { return gtRepo.git_repository() }
  
  var gitDirectoryPath: String
  {
    guard let path = git_repository_path(gitRepo)
    else { return "" }
    
    return String(cString: path)
  }
  
  var gitDirectoryURL: URL
  {
    return URL(fileURLWithPath: gitDirectoryPath)
  }
  
  static func gitPath() -> String?
  {
    let paths = ["/usr/bin/git", "/usr/local/git/bin/git"]
    
    return paths.first(where: { FileManager.default.fileExists(atPath: $0) })
  }
  
  @objc(initWithURL:)
  init?(url: URL)
  {
    guard let gitCMD = XTRepository.gitPath(),
          let gtRepo = try? GTRepository(url: url)
    else { return nil }
    
    self.repoURL = url
    self.gitCMD = gitCMD
    self.gtRepo = gtRepo
    
    self.queue = TaskQueue(id: "com.uncommonplace.xit.\(url.path)")
    
    super.init()
    
    postInit()
  }
  
  @objc(initEmptyWithURL:)
  init?(emptyURL url: URL)
  {
    guard let gitCMD = XTRepository.gitPath(),
          let gtRepo = try? GTRepository.initializeEmpty(atFileURL: url,
                                                         options: nil)
    else { return nil }
    
    self.repoURL = url
    self.gitCMD = gitCMD
    self.gtRepo = gtRepo
    self.queue = TaskQueue(id: "com.uncommonplace.xit.\(url.path)")
    
    super.init()
    
    postInit()
  }
  
  private func postInit()
  {
    self.repoWatcher = XTRepositoryWatcher(repository: self)
    self.workspaceWatcher = WorkspaceWatcher(repository: self)
    self.config = XTConfig(config: GitConfig(repository: gitRepo))
  }
  
  deinit
  {
    repoWatcher.stop()
    workspaceWatcher.stop()
    NotificationCenter.default.removeObserver(self)
  }
  
  func updateIsWriting(_ writing: Bool)
  {
    guard writing != isWriting
    else { return }
    
    mutex.withLock {
      isWriting = writing
    }
  }
  
  func performWriting(_ block: (() throws -> Void)) throws
  {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    
    if isWriting {
      throw Error.alreadyWriting
    }
    updateIsWriting(true)
    defer {
      updateIsWriting(false)
    }
    try block()
  }
  
  func clearCachedBranch()
  {
    mutex.withLock {
      cachedBranch = nil
    }
  }
  
  func refsChanged()
  {
    // In theory the two separate locks could result in cachedBranch being wrong
    // but that would only happen if this function was called on two different
    // threads and one of them found that the branch had just changed again.
    // Not likely.
    guard let newBranch = calculateCurrentBranch(),
          mutex.withLock({ newBranch != cachedBranch })
    else { return }
    
    willChangeValue(forKey: "currentBranch")
    mutex.withLock {
      cachedBranch = newBranch
    }
    didChangeValue(forKey: "currentBranch")
  }
  
  func recalculateHead()
  {
    guard let headReference = self.headReference
    else { return }
    
    switch headReference.type {
      case .symbolic:
        cachedHeadRef = headReference.symbolicTargetName
      case .OID:
        cachedHeadRef = headReference.name
      default:
        break
    }
    cachedHeadSHA = sha(forRef: headReference.name)
  }
  
  func invalidateIndex()
  {
    mutex.withLock {
      cachedStagedChanges = nil
      cachedAmendChanges = nil
      cachedUnstagedChanges = nil
    }
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
  
  func executeGit(args: [String], writes: Bool) throws -> Data
  {
    return try executeGit(args: args, stdInData: nil, writes: writes)
  }
  
  func executeGit(args: [String],
                  stdInData: Data?,
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
      throw Error.alreadyWriting
    }
    updateIsWriting(writes)
    defer {
      updateIsWriting(false)
    }
    executing = true
    defer { executing = false }
    NSLog("*** command = git \(args.joined(separator: " "))")
    
    let task = Process()
    
    task.currentDirectoryPath = repoURL.path
    task.launchPath = gitCMD
    task.arguments = args
    
    // Large files have to be chunked or else FileHandle.write() hangs
    let chunkSize = 10*1024

    if let data = stdInData {
      let stdInPipe = Pipe()
      
      if data.count <= chunkSize {
        stdInPipe.fileHandleForWriting.write(data)
        stdInPipe.fileHandleForWriting.closeFile()
      }
      task.standardInput = stdInPipe
    }
    
    let pipe = Pipe()
    let errorPipe = Pipe()
    
    task.standardOutput = pipe
    task.standardError = errorPipe
    try task.throwingLaunch()
    
    if let data = stdInData,
       data.count > chunkSize,
       let handle = (task.standardInput as? Pipe)?.fileHandleForWriting {
      for chunkIndex in 0...(data.count/chunkSize) {
        let chunkStart = chunkIndex * chunkSize
        let chunkEnd = min(chunkStart + chunkSize, data.count)
        let subData = data.subdata(in: chunkStart..<chunkEnd)
        
        handle.write(subData)
      }
      handle.closeFile()
    }
    
    let output = pipe.fileHandleForReading.readDataToEndOfFile()
    
    task.waitUntilExit()
    
    guard task.terminationStatus == 0
    else {
      let string = String(data: output, encoding: .utf8) ?? "-"
      let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
      let errorString = String(data: errorOutput, encoding: .utf8) ?? "-"
      
      NSLog("**** output = \(string)")
      NSLog("**** error = \(errorString)")
      throw NSError(domain: XTErrorDomainGit, code: Int(task.terminationStatus),
                    userInfo: [XTErrorOutputKey: string,
                               XTErrorArgsKey: args.joined(separator: " ")])
    }
    
    return output
  }
}

// For testing
internal func setRepoWriting(_ repo: XTRepository, _ writing: Bool)
{
  repo.isWriting = writing
}

extension XTRepository: CommitStorage
{
  public func oid(forSHA sha: String) -> OID?
  {
    return GitOID(sha: sha)
  }
  
  public func commit(forSHA sha: String) -> Commit?
  {
    return XTCommit(sha: sha, repository: self)
  }
  
  public func commit(forOID oid: OID) -> Commit?
  {
    return XTCommit(oid: oid, repository: gitRepo)
  }
  
  public func walker() -> RevWalk?
  {
    return GitRevWalk(repository: gitRepo)
  }
}

extension XTRepository
{
  /// Returns true if the path is ignored according to the repository's
  /// ignore rules.
  func isIgnored(path: String) -> Bool
  {
    let ignored = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
    let result = git_ignore_path_is_ignored(ignored, gitRepo, path)

    return (result == 0) && (ignored.pointee != 0)
  }
  
  /// Returns the unstaged and staged status of the given file.
  func status(file: String) throws -> (DeltaStatus, DeltaStatus)
  {
    let statusFlags = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
    let result = git_status_file(statusFlags, gitRepo, file)
    
    if result != 0 {
      throw NSError.git_error(for: result)
    }
    
    let flags = git_status_t(statusFlags.pointee)
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
    let ahead = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    let behind = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    
    if git_graph_ahead_behind(ahead, behind, gitRepo,
                              local.unsafeOID(), upstream.unsafeOID()) == 0 {
      return (ahead.pointee, behind.pointee)
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

extension NSNotification.Name
{
  static let XTRepositoryRefLogChanged =
      NSNotification.Name("XTRepositoryRefLogChanged")
}
