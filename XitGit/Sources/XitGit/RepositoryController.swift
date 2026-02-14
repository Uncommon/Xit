import Foundation
import Combine

public protocol RepositoryController: RepositoryCaching, RepositoryPublishing, AnyObject
{
  var repository: any BasicRepository { get }
  var queue: TaskQueue { get }
}

public struct RepositoryCache
{
  var stagedChanges: [FileChange]?
  var amendChanges: [FileChange]?
  var unstagedChanges: [FileChange]?
  var branches: [String: GitBranch] = [:]

  init() {}

  // Set them all together so the mutex only has to be used once
  mutating func invalidateIndex()
  {
    stagedChanges = nil
    amendChanges = nil
    unstagedChanges = nil
  }
}

/// Manages tasks and data related to working with a repository, such as cached
/// data and things not directly related to repository operations, such as
/// the task queue and tracking file changes.
final class GitRepositoryController: RepositoryController
{
  let xtRepo: XTRepository
  var repository: any BasicRepository { xtRepo }

  public let queue: TaskQueue
  let mutex = NSRecursiveLock()

  fileprivate var repoWatcher: RepositoryWatcher?
  fileprivate let configWatcher: ConfigWatcher
  fileprivate var workspaceWatcher: WorkspaceWatcher?
  private var workspaceSink: AnyCancellable?
  
  var progressSubject = PassthroughSubject<ProgressValue, Never>()

  @MutexProtected(wrappedValue: .init())
  public var cache: RepositoryCache

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

    repoWatcher = RepositoryWatcher(controller: self)
    workspaceWatcher = WorkspaceWatcher(controller: self)

    workspaceSink = workspaceWatcher?.publisher
      .sinkOnMainQueue { // main queue might not be necessary
        [weak self] _ in
        self?.invalidateIndex()
      }
    repository.controller = self
  }
  
  deinit
  {
    repoWatcher?.stop()
    configWatcher.stop()
    workspaceWatcher?.stop()
  }
}

extension GitRepositoryController: RepositoryPublishing
{
  var configPublisher: AnyPublisher<Void, Never> {
    configWatcher.configPublisher
  }

  var headPublisher: AnyPublisher<Void, Never> {
    repoWatcher!.publishers[.head]
  }

  var indexPublisher: AnyPublisher<Void, Never> {
    repoWatcher!.publishers[.index]
  }

  var refLogPublisher: AnyPublisher<Void, Never> {
    repoWatcher!.publishers[.refLog]
  }

  var refsPublisher: AnyPublisher<Void, Never> {
    repoWatcher!.publishers[.refs]
  }

  var stashPublisher: AnyPublisher<Void, Never> {
    repoWatcher!.publishers[.stash]
  }

  var workspacePublisher: AnyPublisher<[String], Never> {
    workspaceWatcher!.publisher
  }
  
  var progressPublisher: AnyPublisher<(current: Float, total: Float), Never> {
    progressSubject.eraseToAnyPublisher()
  }

  func indexChanged() {
    repoWatcher!.publishers.send(.index)
  }

  func refsChanged() {
    repoWatcher?.publishers.send(.refs)
  }
  
  func post(progress: Float, total: Float) {
    progressSubject.send((progress, total))
  }
}

// Caching
extension GitRepositoryController
{
  func addCachedBranch(_ branch: GitBranch)
  {
    cache.branches[branch.name] = branch
  }

  func invalidateIndex()
  {
    cache.invalidateIndex()
  }
}
