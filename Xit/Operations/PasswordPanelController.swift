import Cocoa

final class PasswordPanelController: SheetController
{
  @ControlStringValue var userName: String
  @ControlStringValue var password: String
  @ControlBoolValue var storeInKeychain: Bool
  
  @IBOutlet weak var userField: NSTextField!
  @IBOutlet weak var passwordField: NSSecureTextField!
  @IBOutlet weak var keychainCheck: NSButton!
  
  var semaphore = DispatchSemaphore(value: 0)
  
  deinit
  {
    // Be sure to abort cleanly, especially since getPassword() may be waiting
    // on the semaphore.
    if let window = self.window {
      window.sheetParent?.endSheet(window)
    }
  }
  
  override func windowDidLoad()
  {
    super.windowDidLoad()
    
    $userName = userField
    $password = passwordField
    $storeInKeychain = keychainCheck
  }
  
  /// Blocks the current thread and runs the sheet on the main thread until
  /// the user dismisses the sheet.
  /// - parameter parentWindow: Parent window for the sheet
  /// - parameter host: For keychain storage. If empty, the "Store in keychain"
  /// checkbox will be hidden.
  /// - parameter path: For keychain storage
  /// - parameter port: For keychain storage
  /// - Returns: A tuple containing the user name and password, or `nil` if the
  /// sheet was canceled.
  func getPassword(parentWindow: NSWindow,
                   host: String = "",
                   path: String = "",
                   port: UInt16 = 80) -> (String, String)?
  {
    guard !Thread.isMainThread
    else {
      assertionFailure("getPassword called on the main thread")
      return nil
    }
    var result: (String, String)?
    
    DispatchQueue.main.async { [self] in
      if host.isEmpty {
        keychainCheck.isHidden = true
      }
      
      parentWindow.beginSheet(window!) {
        [self] (response) in
        if response == .OK {
          result = (userName, password)
          if storeInKeychain {
            Self.storeKeychainPassword(host: host, path: path, port: port,
                                       account: userName,
                                       password: password)
          }
        }
        _ = semaphore.signal()
      }
    }
    _ = semaphore.wait(timeout: .distantFuture)
    
    return result
  }
  
  static func storeKeychainPassword(host: String, path: String, port: UInt16,
                                    account: String, password: String)
  {
    DispatchQueue.main.async {
      do {
        try KeychainStorage.shared.save(host: host, path: path, port: port,
                                   account: account, password: password)
      }
      catch let error as NSError {
        NSLog("Keychain save failed: error \(error.code)")
        NSAlert.showMessage(message: .cantSavePassword)
      }
    }
  }
}
