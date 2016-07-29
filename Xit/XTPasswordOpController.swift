import Cocoa

/// An operation that may require a password.
class XTPasswordOpController: XTSimpleOperationController {

  /// User/password callback
  func getPassword() -> (String, String)?
  {
    guard let window = self.windowController?.window
      else { return nil }
    
    let panel = XTPasswordPanelController.controller()
    let semaphore = dispatch_semaphore_create(0)
    var result: (String, String)? = nil
    
    dispatch_async(dispatch_get_main_queue()) {
      window.beginSheet(panel.window!) { (response) in
        if response == NSModalResponseOK {
          result = (panel.userName, panel.password)
        }
        _ = dispatch_semaphore_signal(semaphore)
      }
    }
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
    return result
  }

}
