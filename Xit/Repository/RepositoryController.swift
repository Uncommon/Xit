import Foundation

public protocol RepositoryController: AnyObject
{
  var repository: BasicRepository { get }
  var queue: TaskQueue { get }

  var cachedStagedChanges: [FileChange]? { get set }
  var cachedAmendChanges: [FileChange]? { get set }
  var cachedUnstagedChanges: [FileChange]? { get set }

  func invalidateIndex()
}

/// Manages tasks and data related to working with a repository, such as cached
/// data and things not directly related to repository operations, such as
/// the task queue and tracking file changes.
class GitRepositoryController: NSObject, RepositoryController
{
  let xtRepo: XTRepository
  var repository: BasicRepository { xtRepo }

  @objc public let queue: TaskQueue
  let mutex = Mutex()
  var refsIndex = [String: [String]]()

  fileprivate var repoWatcher: RepositoryWatcher?
  fileprivate let configWatcher: ConfigWatcher
  fileprivate var workspaceWatcher: WorkspaceWatcher?

  fileprivate(set) var cachedHeadRef, cachedHeadSHA, cachedBranch: String?
  
  // Named with an underscore because the public accessors use the mutex
  private var _cachedStagedChanges, _cachedAmendChanges,
              _cachedUnstagedChanges: [FileChange]?
  private var _cachedBranches: [String: GitBranch] = [:]
  
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
  var cachedBranches: [String: GitBranch]
  {
    get { return mutex.withLock { _cachedBranches } }
    set { mutex.withLock { _cachedBranches = newValue } }
  }
  var cachedIgnored = false

  let diffCache = Cache<String, Diff>(maxSize: 50)
  
  
  static func taskQueueID(path: String) -> String
  {
    let identifier = Bundle.main.bundleIdentifier ?? "com.uncommonplace.xit"
    
    return "\(identifier).\(path)"
  }

  init(repository: XTRepository)
  {
    self.xtRepo = repository
    
    self.queue = TaskQueue(id: Self.taskQueueID(path: repository.repoURL.path))
    
    self.configWatcher = ConfigWatcher(repository: repository)
    
    super.init()
    
    self.repoWatcher = RepositoryWatcher(controller: self)
    self.workspaceWatcher = WorkspaceWatcher(controller: self)
    repository.controller = self
  }
  
  deinit
  {
    repoWatcher?.stop()
    configWatcher.stop()
    workspaceWatcher?.stop()
  }
}

// Caching
extension GitRepositoryController
{
  @objc public var currentBranch: String?
  {
    mutex.lock()
    defer { mutex.unlock() }
    if cachedBranch == nil {
      refsChanged()
    }
    return cachedBranch
  }

  func addCachedBranch(_ branch: GitBranch)
  {
    mutex.withLock {
      _cachedBranches[branch.name] = branch
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
    guard let newBranch = xtRepo.calculateCurrentBranch(),
          mutex.withLock({ newBranch != cachedBranch })
    else { return }
    
    changingValue(forKey: #keyPath(currentBranch)) {
      mutex.withLock {
        cachedBranch = newBranch
      }
    }
  }
  
  func invalidateIndex()
  {
    mutex.withLock {
      cachedStagedChanges = nil
      cachedAmendChanges = nil
      cachedUnstagedChanges = nil
    }
  }
}
