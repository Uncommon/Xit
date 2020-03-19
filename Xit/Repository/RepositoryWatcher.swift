import Foundation

let XTAddedRefsKey = "addedRefs"
let XTDeletedRefsKey = "deletedRefs"
let XTChangedRefsKey = "changedRefs"

class RepositoryWatcher
{
  weak var controller: RepositoryController?
  
  var repository: XTRepository? { controller?.repository as? XTRepository }

  // stream must be var because we have to reference self to initialize it.
  var stream: FileEventStream! = nil
  var packedRefsWatcher: FileMonitor?
  var stashWatcher: FileMonitor?
  
  let mutex = Mutex()
  
  private var lastIndexChangeGuarded = Date()
  var lastIndexChange: Date
  {
    get
    {
      return mutex.withLock { lastIndexChangeGuarded }
    }
    set
    {
      mutex.withLock { lastIndexChangeGuarded = newValue }
      controller?.invalidateIndex()
      NotificationCenter.default.post(name: .XTRepositoryIndexChanged,
                                      object: controller?.repository)
    }
  }
  
  var refsCache = [String: GitOID]()

  init?(controller: RepositoryController)
  {
    guard let repository = controller.repository as? XTRepository
    else { return nil }
    
    self.controller = controller
    
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
    refsCache = index(refs: repository.allRefs())
  }
  
  func stop()
  {
    stream.stop()
    mutex.withLock {
      self.packedRefsWatcher = nil
    }
  }
  
  func makePackedRefsWatcher()
  {
    let path = repository!.gitDirectoryPath
    let watcher = FileMonitor(path: path +/ "packed-refs")
    
    mutex.withLock { self.packedRefsWatcher = watcher }
    watcher?.notifyBlock = {
      [weak self] (_, _) in
      self?.checkRefs()
    }
  }
  
  func makeStashWatcher()
  {
    let path = repository!.gitDirectoryPath +/ "logs/refs/stash"
    guard let watcher = FileMonitor(path: path)
    else { return }
    
    stashWatcher = watcher
    watcher.notifyBlock = {
      [weak self] (_, _) in
      self?.post(.XTRepositoryStashChanged)
    }
  }
  
  func index(refs: [String]) -> [String: GitOID]
  {
    var result = [String: GitOID]()
    
    for ref in refs {
      guard let oid = repository?.sha(forRef: ref).flatMap({ GitOID(sha: $0) })
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
  
  func post(_ name: NSNotification.Name)
  {
    DispatchQueue.main.async {
      [weak self] in
      self.map {
        NotificationCenter.default.post(name: name, object: $0.repository)
      }
    }
  }
  
  func checkRefs(changedPaths: [String], repository: XTRepository)
  {
    mutex.withLock {
      if self.packedRefsWatcher == nil,
         changedPaths.firstIndex(of: repository.gitDirectoryPath) != nil {
        self.makePackedRefsWatcher()
      }
    }
    
    if paths(changedPaths, includeSubpaths: ["refs/heads", "refs/remotes"]) {
      checkRefs()
    }
  }
  
  func checkHead(changedPaths: [String], repository: XTRepository)
  {
    if paths(changedPaths, includeSubpaths: ["HEAD"]) {
      repository.clearCachedBranch()
      post(.XTRepositoryHeadChanged)
    }
  }
  
  func checkRefs()
  {
    guard let repository = self.repository
    else { return }
    
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    
    let newRefCache = index(refs: repository.allRefs())
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
    
    var refChanges = [String: Set<String>]()
    
    if !addedRefs.isEmpty {
      refChanges[XTAddedRefsKey] = addedRefs
    }
    if !deletedRefs.isEmpty {
      refChanges[XTDeletedRefsKey] = deletedRefs
    }
    if !changedRefs.isEmpty {
      refChanges[XTChangedRefsKey] = Set(changedRefs)
    }
    
    if !refChanges.isEmpty {
      repository.rebuildRefsIndex()
      post(.XTRepositoryRefsChanged)
      repository.refsChanged()
    }
    
    refsCache = newRefCache
  }
  
  func checkLogs(changedPaths: [String])
  {
    if paths(changedPaths, includeSubpaths: ["logs/refs"]) {
      post(.XTRepositoryRefLogChanged)
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
    
    post(.XTRepositoryChanged)
  }
}
