import Cocoa

/// An operation that may require a password.
class PasswordOpController: SimpleOperationController
{
  /// User/password callback
  func getPassword() -> (String, String)?
  {
    let semaphore = DispatchSemaphore(value: 0)
    var result: (String, String)?
    
    DispatchQueue.main.async {
      guard let window = self.windowController?.window
      else {
        _ = semaphore.signal()
        return
      }
      
      let panel = PasswordPanelController.controller()
      
      window.beginSheet(panel.window!) { (response) in
        if response == .OK {
          result = (panel.userName, panel.password)
        }
        _ = semaphore.signal()
      }
    }
    _ = semaphore.wait(timeout: DispatchTime.distantFuture)
    return result
  }

}
