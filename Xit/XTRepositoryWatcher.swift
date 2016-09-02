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
  var lastIndexChange = NSDate()
  {
    didSet
    {
      NSNotificationCenter.defaultCenter().postNotificationName(
          XTRepositoryIndexChangedNotification, object: repository)
    }
  }
  var refsCache = [String: GTOID]()

  init?(repository: XTRepository)
  {
    guard let path = repository.gitDirectoryURL.path
    else { return nil }
    
    self.repository = repository
    super.init()
    
    makePackedRefsWatcher()

    let latency: CFTimeInterval = 1.0
    let unsafeSelf = UnsafeMutablePointer<Void>(unsafeAddressOf(self))
    var context = FSEventStreamContext(version: 0,
                                       info: unsafeSelf,
                                       retain: nil,
                                       release: nil,
                                       copyDescription: nil)
    let callback: FSEventStreamCallback = {
      (streamRef, userData, eventCount, paths, flags, ids) in
      guard let cfPaths = unsafeBitCast(paths, NSArray.self) as? [String]
      else { return }
      let contextSelf = unsafeBitCast(userData, XTRepositoryWatcher.self)
      
      contextSelf.observeEvents(cfPaths)
    }
  
    self.stream = FSEventStreamCreate(
        kCFAllocatorDefault, callback,
        &context, [path],
        FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency,
        UInt32(kFSEventStreamCreateFlagUseCFTypes |
               kFSEventStreamCreateFlagNoDefer))
    if self.stream == nil {
      return nil
    }
    FSEventStreamScheduleWithRunLoop(self.stream,
                                     CFRunLoopGetMain(),
                                     kCFRunLoopDefaultMode)
    FSEventStreamStart(self.stream)
  }
  
  deinit
  {
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)
  }
  
  func makePackedRefsWatcher()
  {
    guard let path = repository.gitDirectoryURL.path
    else { return }
    
    self.packedRefsWatcher =
        XTFileMonitor(path: path.stringByAppendingPathComponent("packed-refs"))
    self.packedRefsWatcher?.notifyBlock = { (_, _) in self.checkRefs() }
  }
  
  func indexRefs(refs: [String]) -> [String: GTOID]
  {
    var result = [String: GTOID]()
    
    for ref in refs {
      guard let oid = repository.shaForRef(ref).flatMap({ GTOID(SHA: $0) })
      else { continue }
      
      result[ref] = oid
    }
    return result
  }
  
  func checkIndex()
  {
    guard let gitPath = repository.gitDirectoryURL.path
    else { return }
    let indexPath = gitPath.stringByAppendingPathComponent("index")
    guard let indexAttributes = try? NSFileManager.defaultManager()
                                     .attributesOfItemAtPath(indexPath),
          let newMod = indexAttributes[NSFileModificationDate] as? NSDate
    else {
      lastIndexChange = NSDate.distantPast()
      return
    }
    
    if lastIndexChange.compare(newMod) != .OrderedSame {
      lastIndexChange = newMod
    }
  }
  
  func paths(paths: [String], includeSubpaths subpaths: [String]) -> Bool
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
  
  func checkRefs(changedPaths: [String])
  {
    if packedRefsWatcher == nil,
       let path = repository.gitDirectoryURL.path where
       changedPaths.indexOf(path) != nil {
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
    let addedRefs = newKeys.subtract(oldKeys)
    let deletedRefs = oldKeys.subtract(newKeys)
    let changedRefs = newKeys.subtract(addedRefs).filter {
      (ref) -> Bool in
      guard let oldOID = refsCache[ref],
            let newSHA = self.repository.shaForRef(ref),
            let newOID =  GTOID(SHA: newSHA)
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
      NSNotificationCenter.defaultCenter().postNotificationName(
          XTRepositoryRefsChangedNotification, object: repository)
    }
    
    refsCache = newRefCache
  }
  
  func observeEvents(paths: [String])
  {
    // FSEvents includes trailing slashes, but some other APIs don't.
    let standardPaths = paths.map({ ($0 as NSString).stringByStandardizingPath })
  
    checkIndex()
    checkRefs(standardPaths)
    
    NSNotificationCenter.defaultCenter().postNotificationName(
        XTRepositoryChangedNotification, object: repository)
  }
}
