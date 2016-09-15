import Foundation

let XTAddedRefsKey = "addedRefs"
let XTDeletedRefsKey = "deletedRefs"
let XTChangedRefsKey = "changedRefs"

// Remove inheritance when XTRepository is converted to Swift
@objc class XTRepositoryWatcher: NSObject
{
  unowned let repository: XTRepository

  // stream must be var because we have to reference self to initialize it.
  var stream: FSEventStreamRef!
  var packedRefsWatcher: XTFileMonitor?
  var lastIndexChange = Date()
  {
    didSet
    {
      NotificationCenter.default.post(
          name: NSNotification.Name.XTRepositoryIndexChanged, object: repository)
    }
  }
  var refsCache = [String: GTOID]()

  init?(repository: XTRepository)
  {
    self.repository = repository
    super.init()
    
    makePackedRefsWatcher()

    let latency: CFTimeInterval = 1.0
    let unsafeSelf = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    var context = FSEventStreamContext(version: 0,
                                       info: unsafeSelf,
                                       retain: nil,
                                       release: nil,
                                       copyDescription: nil)
    let callback: FSEventStreamCallback = {
      (streamRef, userData, eventCount, paths, flags, ids) in
      guard let cfPaths = unsafeBitCast(paths, to: NSArray.self) as? [String]
      else { return }
      let contextSelf = unsafeBitCast(userData, to: XTRepositoryWatcher.self)
      
      contextSelf.observeEvents(cfPaths)
    }
  
    self.stream = FSEventStreamCreate(
        kCFAllocatorDefault, callback,
        &context, [repository.gitDirectoryURL.path] as CFArray,
        FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency,
        UInt32(kFSEventStreamCreateFlagUseCFTypes |
               kFSEventStreamCreateFlagNoDefer))
    if self.stream == nil {
      return nil
    }
    FSEventStreamScheduleWithRunLoop(self.stream,
                                     CFRunLoopGetMain(),
                                     CFRunLoopMode.defaultMode.rawValue)
    FSEventStreamStart(self.stream)
  }
  
  func stop()
  {
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)
    stream = nil
    packedRefsWatcher = nil
  }
  
  func makePackedRefsWatcher()
  {
    let path = repository.gitDirectoryURL.path
    
    self.packedRefsWatcher =
        XTFileMonitor(path: path.stringByAppendingPathComponent("packed-refs"))
    self.packedRefsWatcher?.notifyBlock = {
      [weak self] (_, _) in
      self?.checkRefs()
    }
  }
  
  func indexRefs(_ refs: [String]) -> [String: GTOID] //!
  {
    var result = [String: GTOID]()
    
    for ref in refs {
      guard let oid = repository.sha(forRef: ref).flatMap({ GTOID(sha: $0) })
      else { continue }
      
      result[ref] = oid
    }
    return result
  }
  
  func checkIndex()
  {
    let gitPath = repository.gitDirectoryURL.path
    let indexPath = gitPath.stringByAppendingPathComponent("index")
    guard let indexAttributes = try? FileManager.default
                                     .attributesOfItem(atPath: indexPath),
          let newMod = indexAttributes[FileAttributeKey.modificationDate] as? Date
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
          path.stringByDeletingLastPathComponent.hasSuffix(subpath) {
          return true
        }
      }
    }
    return false
  }
  
  func checkRefs(_ changedPaths: [String])
  {
    if packedRefsWatcher == nil,
       changedPaths.index(of: repository.gitDirectoryURL.path) != nil {
      makePackedRefsWatcher()
    }
    
    if paths(changedPaths, includeSubpaths: ["refs/heads", "refs/remotes"]) {
      checkRefs()
    }
  }
  
  func checkRefs()
  {
    let newRefCache = indexRefs(repository.allRefs())
    let newKeys = Set(newRefCache.keys)
    let oldKeys = Set(refsCache.keys)
    let addedRefs = newKeys.subtracting(oldKeys)
    let deletedRefs = oldKeys.subtracting(newKeys)
    let changedRefs = newKeys.subtracting(addedRefs).filter {
      (ref) -> Bool in
      guard let oldOID = refsCache[ref],
            let newSHA = self.repository.sha(forRef: ref),
            let newOID =  GTOID(sha: newSHA)
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
      NotificationCenter.default.post(
          name: NSNotification.Name.XTRepositoryRefsChanged, object: repository)
    }
    
    refsCache = newRefCache
  }
  
  func observeEvents(_ paths: [String])
  {
    // FSEvents includes trailing slashes, but some other APIs don't.
    let standardPaths = paths.map({ ($0 as NSString).standardizingPath })
  
    checkIndex()
    checkRefs(standardPaths)
    
    NotificationCenter.default.post(
        name: NSNotification.Name.XTRepositoryChanged, object: repository)
  }
}
