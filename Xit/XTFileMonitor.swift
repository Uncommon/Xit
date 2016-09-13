  import Foundation

let kSourceMask: UInt =
    DISPATCH_VNODE_DELETE | DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND |
    DISPATCH_VNODE_ATTRIB | DISPATCH_VNODE_LINK | DISPATCH_VNODE_RENAME |
    DISPATCH_VNODE_REVOKE

class XTFileMonitor {
  
  let path: String
  let fd: CInt
  let source: dispatch_source_t
  
  var notifyBlock: ((path: String, flags: UInt) -> Void)?
  
  init?(path: String)
  {
    self.path = path
    self.fd = open(path, O_EVTONLY)
    
    guard fd >= 0
    else { return nil }
    
    guard let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                0),
          let source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,
                                              UInt(fd), kSourceMask, queue)
    else { return nil }
    self.source = source
    
    dispatch_source_set_event_handler(source) {
      [weak self] in
      self?.notifyBlock?(path: self!.path,
                         flags: dispatch_source_get_data(source))
    }
    
    dispatch_resume(source);
  }
  
  deinit
  {
    dispatch_source_cancel(source);
    close(fd)
  }
}
