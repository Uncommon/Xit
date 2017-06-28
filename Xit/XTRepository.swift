import Foundation


public protocol RepositoryType: class
{
  associatedtype C: CommitType
  
  func commit(forSHA sha: String) -> C?
  func commit(forOID oid: C.ID) -> C?
}

public protocol CommitReferencing
{
  associatedtype LocalBranchSequence: Sequence
  associatedtype RemoteBranchSequence: Sequence

  var headRef: String? { get }
  var currentBranch: String? { get }
  func remoteNames() -> [String]
  func localBranches() -> LocalBranchSequence
  func remoteBranches() -> RemoteBranchSequence
  func tags() throws -> [Tag]
  func graphBetween(localBranch: XTLocalBranch,
                    upstreamBranch: XTRemoteBranch) ->(ahead: Int,
                                                       behind: Int)?
}

public protocol SubmoduleManagement
{
  func submodules() -> [XTSubmodule]
  func addSubmodule(path: String, url: String) throws
}

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
  let repoURL: URL
  let gitCMD: String
  let queue: TaskQueue
  var refsIndex = [String: [String]]()
  fileprivate(set) var isWriting = false
  fileprivate var executing = false
  
  fileprivate(set) var cachedHeadRef, cachedHeadSHA, cachedBranch: String?
  
  let diffCache = NSCache<NSString, GTDiff>()
  fileprivate var repoWatcher: XTRepositoryWatcher! = nil
  fileprivate var workspaceWatcher: WorkspaceWatcher! = nil
  private(set) var config: XTConfig! = nil
  
  var gitDirectoryURL: URL
  {
    return gtRepo.gitDirectoryURL ?? URL(fileURLWithPath: "")
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
    self.config = XTConfig(repository: self)
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
    
    objc_sync_enter(self)
    defer {
      objc_sync_exit(self)
    }
    
    isWriting = writing
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
    cachedBranch = nil
  }
  
  func refsChanged()
  {
    guard let newBranch = calculateCurrentBranch(),
          newBranch != cachedBranch
    else { return }
    
    willChangeValue(forKey: "currentBranch")
    cachedBranch = newBranch
    didChangeValue(forKey: "currentBranch")
  }
  
  func recalculateHead()
  {
    guard let head = parseSymbolicReference("HEAD")
    else { return }
    let ref = head.hasPrefix("refs/heads/") ? head : "HEAD"
    
    cachedHeadRef = ref
    cachedHeadSHA = sha(forRef: ref)
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
                  stdIn: String? = nil,
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
    
    if let stdInData = stdIn?.data(using: .utf8) {
      let stdInPipe = Pipe()
      
      stdInPipe.fileHandleForWriting.write(stdInData)
      stdInPipe.fileHandleForWriting.closeFile()
      task.standardInput = stdInPipe
    }
    
    let pipe = Pipe()
    let errorPipe = Pipe()
    
    task.standardOutput = pipe
    task.standardError = errorPipe
    try task.throwingLaunch()
    
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

extension XTRepository
{
  enum Error: Swift.Error
  {
    case alreadyWriting
    case mergeInProgress
    case cherryPickInProgress
    case conflict  // List of conflicted files
    case localConflict
    case detachedHead
    case gitError(Int32)
    case patchMismatch
    case unexpected
    
    var message: String
    {
      switch self {
        case .alreadyWriting:
          return "A writing operation is already in progress."
        case .mergeInProgress:
          return "A merge operation is already in progress."
        case .cherryPickInProgress:
          return "A cherry-pick operation is already in progress."
        case .conflict:
          return "The operation could not be completed because there were " +
          "conflicts."
        case .localConflict:
          return "There are conflicted files in the work tree or index. " +
          "Try checking in or stashing your changes first."
        case .detachedHead:
          return "This operation cannot be performed in a detached HEAD state."
        case .gitError(let code):
          return "An internal git error (\(code)) occurred."
        case .patchMismatch:
          return "The patch could not be applied because it did not match " +
          "the file content."
        case .unexpected:
          return "An unexpected repository error occurred."
      }
    }
    
    init(gitCode: git_error_code)
    {
      switch gitCode {
        case GIT_ECONFLICT, GIT_EMERGECONFLICT:
          self = .conflict
        case GIT_ELOCKED:
          self = .alreadyWriting
        default:
          self = .gitError(gitCode.rawValue)
      }
    }
    
    init(gitNSError: NSError)
    {
      if gitNSError.domain == GTGitErrorDomain {
        self = .gitError(Int32(gitNSError.code))
      }
      else {
        self = .unexpected
      }
    }
  }
}

// For testing
internal func setRepoWriting(_ repo: XTRepository, _ writing: Bool)
{
  repo.isWriting = writing
}

extension XTRepository: RepositoryType
{
  public typealias ID = GitOID
  public typealias C = XTCommit

  public func commit(forSHA sha: String) -> XTCommit?
  {
    return XTCommit(sha: sha, repository: self)
  }
  
  public func commit(forOID oid: GitOID) -> XTCommit?
  {
    return XTCommit(oid: oid, repository: self)
  }
}

extension XTRepository
{
  /// Returns a file URL for a given relative path.
  func fileURL(_ file: String) -> URL
  {
    return repoURL.appendingPathComponent(file)
  }
  
  /// Returns true if the path is ignored according to the repository's
  /// ignore rules.
  func isIgnored(path: String) -> Bool
  {
    let ignored = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
    let result = git_ignore_path_is_ignored(ignored,
                                            gtRepo.git_repository(),
                                            path)

    return (result == 0) && (ignored.pointee != 0)
  }
  
  func commitForStash(at index: UInt) -> XTCommit?
  {
    guard let stashRef = try? gtRepo.lookUpReference(withName: "refs/stash"),
          let stashLog = GTReflog(reference: stashRef),
          index < stashLog.entryCount,
          let entry = stashLog.entry(at: index),
          let oid = entry.updatedOID.map({ GitOID(oid: $0.git_oid().pointee) })
    else { return nil }
    
    return XTCommit(oid: oid, repository: self)
  }
  
  /// Returns the unstaged and staged status of the given file.
  func status(file: String) throws -> (XitChange, XitChange)
  {
    let statusFlags = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
    let result = git_status_file(statusFlags, gtRepo.git_repository(), file)
    
    if result != 0 {
      throw NSError.git_error(for: result)
    }
    
    let flags = git_status_t(statusFlags.pointee)
    var unstagedChange = XitChange.unmodified
    var stagedChange = XitChange.unmodified
    
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
  
  /// Reverts the given workspace file to the contents at HEAD.
  @objc(revertFile:error:)
  func revert(file: String) throws
  {
    let status = try self.status(file: file)
    
    if status.0 == .untracked {
      try FileManager.default.removeItem(at: repoURL.appendingPathComponent(file))
    }
    else {
      var options = git_checkout_options.defaultOptions()
      var error: Error? = nil
      
      git_checkout_init_options(&options, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
      [file].withGitStringArray {
        (stringarray) in
        options.checkout_strategy = GIT_CHECKOUT_FORCE.rawValue +
                                    GIT_CHECKOUT_RECREATE_MISSING.rawValue
        options.paths = stringarray
        
        let result = git_checkout_tree(self.gtRepo.git_repository(), nil, &options)
        
        if result < 0 {
          error = Error.gitError(result)
        }
      }
      
      try error.map { throw $0 }
    }
  }
  
  func graphBetween(local: GitOID, upstream: GitOID) -> (ahead: Int,
                                                         behind: Int)?
  {
    let ahead = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    let behind = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    
    if git_graph_ahead_behind(ahead, behind, gtRepo.git_repository(),
                              local.unsafeOID(), upstream.unsafeOID()) == 0 {
      return (ahead.pointee, behind.pointee)
    }
    else {
      return nil
    }
  }
  
  public func graphBetween(localBranch: XTLocalBranch,
                           upstreamBranch: XTRemoteBranch) ->(ahead: Int,
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
