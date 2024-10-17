import Foundation
import Combine

/// Watches the repository for changes on disk, and publishes them.
final class RepositoryWatcher
{
  public enum RefKey
  {
    static let added = "addedRefs"
    static let deleted = "deletedRefs"
    static let changed = "changedRefs"
  }

  weak var controller: RepositoryController?
  
  var repository: XTRepository? { controller?.repository as? XTRepository }

  // stream must be var because we have to reference self to initialize it.
  var stream: FileEventStream! = nil
  var packedRefsWatcher: FileMonitor?
  var stashWatcher: FileMonitor?

  enum Notification: CaseIterable
  {
    case head, index, refLog, refs, stash
  }

  let publishers = PublisherGroup<Void, Never, Notification>()

  let mutex = NSRecursiveLock()
  
  private var lastIndexChangeGuarded = Date()
  var lastIndexChange: Date
  {
    get
    { mutex.withLock { lastIndexChangeGuarded } }
    set
    {
      mutex.withLock { lastIndexChangeGuarded = newValue }
      controller?.invalidateIndex()
      publishers.send(.index)
    }
  }
  
  var refsCache: [GeneralRefName: GitOID]

  var packedRefsSink, stashSink: AnyCancellable?

  init?(controller: RepositoryController)
  {
    guard let repository = controller.repository as? XTRepository
    else { return nil }
    
    self.controller = controller
    self.refsCache = Self.index(from: repository)

    let gitPath = repository.gitDirectoryPath
    let objectsPath = gitPath.appending(pathComponent: "objects")
    guard let stream = FileEventStream(path: gitPath,
                                       excludePaths: [objectsPath],
                                       queue: controller.queue.queue,
                                       callback: {
      [weak self] (paths) in
      // Capture the repository here in case it gets deleted on another thread
      guard let self = self,
            let repository = self.controller?.repository as? XTRepository
      else { return }
      
      self.observeEvents(paths, repository)
    })
    else { return nil }
  
    self.stream = stream
    makePackedRefsWatcher()
    makeStashWatcher()
  }
  
  func stop()
  {
    stream.stop()
    mutex.withLock {
      packedRefsWatcher = nil
    }
  }
  
  func makePackedRefsWatcher()
  {
    let path = repository!.gitDirectoryPath
    let watcher = FileMonitor(path: path +/ "packed-refs")
    
    if let watcher {
      mutex.withLock { packedRefsWatcher = watcher }
      packedRefsSink = watcher.eventPublisher.sink {
        [weak self] (_, _) in
        self?.checkRefs()
      }
    }
  }
  
  func makeStashWatcher()
  {
    let path = repository!.gitDirectoryPath +/ "logs/refs/stash"
    guard let watcher = FileMonitor(path: path)
    else { return }
    
    stashWatcher = watcher
    stashSink = watcher.eventPublisher.sink {
      [weak self] (_, _) in
      self?.publishers.send(.stash)
    }
  }
  
  static func index(from repository: XTRepository) -> [GeneralRefName: GitOID]
  {
    let refs = repository.allRefs()
    var result = [GeneralRefName: GitOID]()

    for ref in refs {
      guard let oid = repository.sha(forRef: ref).flatMap({ GitOID(sha: $0) })
      else { continue }
      
      result[ref] = oid
    }
    return result
  }
  
  func checkIndex(repository: XTRepository)
  {
    let gitPath = repository.gitDirectoryPath
    let indexPath = gitPath.appending(pathComponent: "index")
    guard let indexAttributes = try? FileManager.default
                                     .attributesOfItem(atPath: indexPath),
          let newMod = indexAttributes[FileAttributeKey.modificationDate]
                       as? Date
    else {
      lastIndexChange = Date.distantPast
      return
    }
    
    if lastIndexChange.compare(newMod) != .orderedSame {
      lastIndexChange = newMod
    }
  }
  
  func paths(_ paths: [String], includeSubpaths subpaths: [String]) -> Bool
  {
    for path in paths {
      for subpath in subpaths {
        if path.hasSuffix(subpath) ||
           path.deletingLastPathComponent.hasSuffix(subpath) {
          return true
        }
      }
    }
    return false
  }
  
  func checkRefs(changedPaths: [String], repository: XTRepository)
  {
    mutex.withLock {
      if packedRefsWatcher == nil,
         changedPaths.contains(repository.gitDirectoryPath) {
        makePackedRefsWatcher()
      }
    }

    let refPaths = [
      "refs/heads",
      "refs/remotes",
      "refs/tags",
    ]
    
    if paths(changedPaths, includeSubpaths: refPaths) {
      checkRefs()
    }
  }
  
  func checkHead(changedPaths: [String], repository: XTRepository)
  {
    if paths(changedPaths, includeSubpaths: ["HEAD"]) {
      repository.clearCachedBranch()
      publishers.send(.head)
    }
  }
  
  func checkRefs()
  {
    guard let repository = self.repository
    else { return }
    
    mutex.lock()
    defer { mutex.unlock() }
    
    let newRefCache = Self.index(from: repository)
    let newKeys = Set(newRefCache.keys)
    let oldKeys = Set(refsCache.keys)
    let addedRefs = newKeys.subtracting(oldKeys)
    let deletedRefs = oldKeys.subtracting(newKeys)
    let changedRefs = newKeys.subtracting(addedRefs).filter {
      (ref) -> Bool in
      guard let oldOID = refsCache[ref],
            let newSHA = repository.sha(forRef: ref),
            let newOID =  GitOID(sha: newSHA)
      else { return false }
      
      return oldOID != newOID
    }
    
    var refChanges = [String: Set<GeneralRefName>]()
    
    if !addedRefs.isEmpty {
      refChanges[RefKey.added] = addedRefs
    }
    if !deletedRefs.isEmpty {
      refChanges[RefKey.deleted] = deletedRefs
    }
    if !changedRefs.isEmpty {
      refChanges[RefKey.changed] = Set(changedRefs)
    }
    
    if !refChanges.isEmpty {
      repository.rebuildRefsIndex()
      publishers.send(.refs)
      repository.refsChanged()
    }
    
    refsCache = newRefCache
  }
  
  func checkLogs(changedPaths: [String])
  {
    if paths(changedPaths, includeSubpaths: ["logs/refs"]) {
      publishers.send(.refLog)
    }
  }
  
  func observeEvents(_ paths: [String], _ repository: XTRepository)
  {
    // FSEvents includes trailing slashes, but some other APIs don't.
    let standardizedPaths = paths.map { ($0 as NSString).standardizingPath }
  
    checkIndex(repository: repository)
    checkHead(changedPaths: standardizedPaths, repository: repository)
    checkRefs(changedPaths: standardizedPaths, repository: repository)
    checkLogs(changedPaths: standardizedPaths)
  }
}
