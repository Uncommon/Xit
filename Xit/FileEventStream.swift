import Foundation

/// Wrapper for FSEventStream.
public class FileEventStream
{
  var stream: FSEventStreamRef!
  let eventCallback: ([String]) -> Void
  
  static let rescanFlags =
      UInt32(kFSEventStreamEventFlagMustScanSubDirs) |
      UInt32(kFSEventStreamEventFlagUserDropped) |
      UInt32(kFSEventStreamEventFlagKernelDropped)
  
  public var latestEventID: FSEventStreamEventId
  { return FSEventStreamGetLatestEventId(stream) }
  
  /// Constructor
  /// - parameter path: The root path to watch.
  /// - parameter excludePaths: FSEvents allows up to 8 ignored paths.
  /// - parameter queue: The dispatch queue for the callback.
  /// - parameter callback: Called with a list of changed paths. An empty list
  /// means the root directory should be re-scanned.
  public init?(path: String,
               excludePaths: [String],
               queue: DispatchQueue,
               latency: CFTimeInterval = 0.5,
               callback: @escaping ([String]) -> Void)
  {
    self.eventCallback = callback
    
    let unsafeSelf = UnsafeMutableRawPointer(
        Unmanaged.passUnretained(self).toOpaque())
    // Must be var because it will be passed by reference
    var context = FSEventStreamContext(version: 0,
                                       info: unsafeSelf,
                                       retain: nil,
                                       release: nil,
                                       copyDescription: nil)
    let callback: FSEventStreamCallback = {
      (streamRef, userData, eventCount, paths, flags, ids) in
      guard let cfPaths = unsafeBitCast(paths, to: NSArray.self) as? [String]
      else { return }
      let contextSelf = unsafeBitCast(userData, to: FileEventStream.self)
      
      if let flags = flags {
        for index in 0..<eventCount {
          let pathFlags = flags[index]
          
          if (pathFlags & FileEventStream.rescanFlags) != 0 {
            contextSelf.eventCallback([])
            return
          }
        }
      }
      
      contextSelf.eventCallback(cfPaths)
    }
    
    self.stream = FSEventStreamCreate(
        kCFAllocatorDefault, callback,
        &context, [path] as CFArray,
        FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency,
        UInt32(kFSEventStreamCreateFlagUseCFTypes |
               kFSEventStreamCreateFlagNoDefer |
               kFSEventStreamCreateFlagFileEvents))
    if self.stream == nil {
      return nil
    }
    
    if !excludePaths.isEmpty {
      FSEventStreamSetExclusionPaths(self.stream, excludePaths as CFArray)
    }
    FSEventStreamSetDispatchQueue(self.stream, queue)
    FSEventStreamStart(self.stream)
  }
  
  deinit
  {
    if stream != nil {
      stop()
    }
  }
  
  public func stop()
  {
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)
    stream = nil
  }
}

/// Wrapper to expose FileEventStream to ObjC
public class XTFileEventStream : NSObject
{
  let stream: FileEventStream

  public init?(path: String,
               excludePaths: [String],
               queue: DispatchQueue,
               latency: CFTimeInterval = 0.5,
               callback: @escaping ([String]) -> Void)
  {
    guard let stream = FileEventStream(path: path, excludePaths: excludePaths,
                                       queue: queue, callback: callback)
    else { return nil }
    
    self.stream = stream
  }
}
