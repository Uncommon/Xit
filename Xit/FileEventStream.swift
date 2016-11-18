import Foundation

/// Wrapper for FSEventStream.
public class FileEventStream
{
  var stream: FSEventStreamRef!
  let eventCallback: ([String]) -> Void
  
  public var latestEventID: FSEventStreamEventId
  { return FSEventStreamGetLatestEventId(stream) }
  
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
