import Foundation

class XTFileMonitor {
  
  let path: String
  let fd: CInt
  let source: DispatchSourceProtocol
  
  var notifyBlock: ((_ path: String, _ flags: UInt) -> Void)?
  
  init?(path: String)
  {
    self.path = path
    self.fd = open(path, O_EVTONLY)
    
    guard fd >= 0
    else { return nil }
    
    let queue = DispatchQueue.global()
    let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: fd,
        eventMask: [.delete, .write, .extend, .attrib, .link, .rename, .revoke],
        queue: queue)

    self.source = source
    
    source.setEventHandler {
      [weak self] in
      self?.notifyBlock?(self!.path,
                         source.data)
    }
    
    source.resume();
  }
  
  deinit
  {
    source.cancel();
    close(fd)
  }
}
