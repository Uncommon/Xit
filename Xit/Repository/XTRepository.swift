import Foundation
import Combine
import os

let repoLogger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                        category: "repo")

/// Stores a repo reference for C callbacks
struct CallbackPayload { let repo: XTRepository }

let kEmptyTreeHash = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
let XTPathsKey = "paths"

public final class XTRepository: BasicRepository, RepoConfiguring
{
  let gitRepo: OpaquePointer
  @objc public let repoURL: URL
  let gitRunner: CLIRunner
  let mutex = Mutex()
  var refsIndex = [String: [String]]()

  let currentBranchSubject = CurrentValueSubject<String?, Never>(nil)
  
  public weak var controller: RepositoryController? = nil
  
  fileprivate(set) public var isWriting = false

  fileprivate(set) var cachedHeadRef, cachedHeadSHA: String?
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
    get { controller?.cachedBranches ?? [:] }
    set { controller?.cachedBranches = newValue }
  }
  var cachedIgnored = false

  let diffCache = Cache<String, any Diff>(maxSize: 50)
  public let config: any Config
  
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

  static func globalCLIRunner() -> CLIRunner?
  {
    gitPath().map { .init(toolPath: $0, workingDir: "~") }
  }
  
  init(gitRepo: OpaquePointer) throws
  {
    guard let gitCmd = XTRepository.gitPath(),
          let workDirPath = git_repository_workdir(gitRepo),
          let config = GitConfig(repository: gitRepo)
    else { throw RepoError.unexpected }
    let url = URL(fileURLWithPath: String(cString: workDirPath))

    self.gitRepo = gitRepo
    self.repoURL = url
    self.gitRunner = CLIRunner(toolPath: gitCmd,
                               workingDir: url.path)
    self.config = config
  }
  
  @objc(initWithURL:)
  convenience init?(url: URL)
  {
    guard url.isFileURL
    else { return nil }
    let path = (url.path as NSString).fileSystemRepresentation
    guard let repo = try? OpaquePointer.from({
      git_repository_open(&$0, path) })
    else { return nil }

    do {
      try self.init(gitRepo: repo)
    }
    catch {
      return nil
    }
  }
  
  convenience init(emptyURL url: URL) throws
  {
    let path = (url.path as NSString).fileSystemRepresentation
    let repo = try OpaquePointer.from({
      git_repository_init(&$0, path, 0) })

    try self.init(gitRepo: repo)
  }
  
  func addCachedBranch(_ branch: GitBranch)
  {
    controller?.cachedBranches[branch.name] = branch
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
      currentBranchSubject.value = nil
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
          mutex.withLock({ newBranch != currentBranchSubject.value })
    else { return }

    currentBranchSubject.value = newBranch
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
  func graphBetween(local: any OID, upstream: any OID) -> (ahead: Int,
                                                           behind: Int)?
  {
    guard let local = local as? GitOID,
          let upstream = upstream as? GitOID
    else { return nil }
    var ahead = 0
    var behind = 0
    let graphResult = local.withUnsafeOID { localOID in
      upstream.withUnsafeOID { upstreamOID in
        git_graph_ahead_behind(&ahead, &behind, gitRepo,
                               localOID, upstreamOID)
      }
    }
    
    if graphResult == 0 {
      return (ahead, behind)
    }
    else {
      return nil
    }
  }
  
  public func graphBetween(localBranch: any LocalBranch,
                           upstreamBranch: any RemoteBranch) ->(ahead: Int,
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
