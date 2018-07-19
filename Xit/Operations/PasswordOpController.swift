import Cocoa

/// An operation that may require a password.
class PasswordOpController: SimpleOperationController
{
  /// User/password callback
  func getPassword() -> (String, String)?
  {
    guard let window = windowController?.window
    else { return nil }
    
    let panel = PasswordPanelController.controller()
    let semaphore = DispatchSemaphore(value: 0)
    var result: (String, String)? = nil
    
    DispatchQueue.main.async {
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
