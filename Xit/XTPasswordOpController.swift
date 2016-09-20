import Cocoa

/// An operation that may require a password.
class XTPasswordOpController: XTSimpleOperationController
{
  /// User/password callback
  func getPassword() -> (String, String)?
  {
    guard let window = self.windowController?.window
    else { return nil }
    
    let panel = XTPasswordPanelController.controller()
    let semaphore = DispatchSemaphore(value: 0)
    var result: (String, String)? = nil
    
    DispatchQueue.main.async {
      window.beginSheet(panel.window!) { (response) in
        if response == NSModalResponseOK {
          result = (panel.userName, panel.password)
        }
        _ = semaphore.signal()
      }
    }
    _ = semaphore.wait(timeout: DispatchTime.distantFuture)
    return result
  }

}
