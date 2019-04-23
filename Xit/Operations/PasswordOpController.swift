import Cocoa

/// An operation that may require a password.
class PasswordOpController: SimpleOperationController
{
  var host = ""
  var path = ""
  var port = 80
  let semaphore = DispatchSemaphore(value: 0)
  var closeObserver: NSObjectProtocol?

  required init(windowController: XTWindowController)
  {
    super.init(windowController: windowController)
    
    let nc = NotificationCenter.default
    
    closeObserver = nc.addObserver(forName: NSWindow.willCloseNotification,
                                   object: windowController.window,
                                   queue: .main) {
      (_) in
      self.semaphore.signal()
    }
  }
  
  deinit
  {
    if let observer = closeObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }
  
  override func abort()
  {
    self.semaphore.signal()
  }
  
  /// User/password callback
  func getPassword() -> (String, String)?
  {
    var result: (String, String)?
    
    DispatchQueue.main.async {
      guard let window = self.windowController?.window
      else {
        _ = self.semaphore.signal()
        return
      }
      
      let panel = PasswordPanelController.controller()

      if self.host.isEmpty {
        panel.keychainCheck.isHidden = true
      }
      
      window.beginSheet(panel.window!) { (response) in
        if response == .OK {
          result = (panel.userName, panel.password)
          if panel.storeInKeychain {
            self.storeKeychainPassword(host: self.host, path: self.path,
                                       port: UInt16(self.port),
                                       account: panel.userName,
                                       password: panel.password)
          }
        }
        _ = self.semaphore.signal()
      }
    }
    _ = semaphore.wait(timeout: DispatchTime.distantFuture)
    return result
  }
  
  func storeKeychainPassword(host: String, path: String, port: UInt16,
                             account: String, password: String)
  {
    self.onSuccess {
      DispatchQueue.main.async {
        do {
          try XTKeychain.shared.save(host: host, path: path, port: port,
                                     account: account, password: password)
        }
        catch let error as NSError {
          NSLog("Keychain save failed: error \(error.code)")
          NSAlert.showMessage(message: .cantSavePassword)
        }
      }
    }
  }
  
  func setKeychainInfoURL(_ url: URL)
  {
    host = url.host ?? ""
    path = url.path
    port = url.port ?? url.defaultPort
  }
}
