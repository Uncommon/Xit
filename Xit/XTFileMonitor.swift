import Foundation

class XTFileMonitor {
  
  let path: String
  let fd: CInt
  let source: DispatchSourceProtocol
  
  var notifyBlock: ((_ path: String, _ flags: UInt) -> Void)?
  
  init?(path: String)
  {
    self.fd = open(path, O_EVTONLY)
    
    guard fd >= 0
    else { return nil }
    
    self.path = path
    self.source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: fd,
        eventMask: [.delete, .write, .extend, .attrib, .link, .rename, .revoke],
        queue: DispatchQueue.global())
    
    source.setEventHandler {
      [weak self] in
      self?.notifyBlock?(self!.path,
                         self!.source.data)
    }
    source.resume();
  }
  
  deinit
  {
    source.cancel();
    close(fd)
  }
}
