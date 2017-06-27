import Foundation

class XTFileMonitor
{
  let path: String
  var fd: CInt = -1
  var source: DispatchSourceFileSystemObject?
  
  var notifyBlock: ((_ path: String, _ flags: UInt) -> Void)?
  
  init?(path: String)
  {
    self.path = path
    makeSource()
    if self.source == nil {
      return nil
    }
  }
  
  func makeSource()
  {
    fd = open(path, O_EVTONLY)
    guard fd >= 0
    else { return }
    
    let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: fd,
        eventMask: [.delete, .write, .extend, .attrib, .link, .rename, .revoke],
        queue: DispatchQueue.global())
    
    source.setEventHandler {
      [weak self] in
      guard let myself = self,
            let source = myself.source
      else { return }
      
      myself.notifyBlock?(myself.path, source.data)
      if source.data.contains(.delete) {
        source.cancel()
        close(myself.fd)
        myself.source = nil
        myself.makeSource()
      }
    }
    source.resume()
    self.source = source
  }
  
  deinit
  {
    source?.cancel()
    close(fd)
  }
}
