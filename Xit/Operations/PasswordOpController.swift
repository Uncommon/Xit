import Cocoa

/// An operation that may require a password.
class PasswordOpController: SimpleOperationController
{
  var host = ""
  var path = ""
  var port = 80
  private(set) var passwordController: PasswordPanelController?
  private var closeObserver: NSObjectProtocol?

  required init(windowController: XTWindowController)
  {
    super.init(windowController: windowController)
    
    let nc = NotificationCenter.default
    
    closeObserver = nc.addObserver(forName: NSWindow.willCloseNotification,
                                   object: windowController.window,
                                   queue: .main) {
      (_) in
      self.abort()
    }
  }

  deinit
  {
    closeObserver.map { NotificationCenter.default.removeObserver($0) }
  }
  
  override func abort()
  {
    passwordController = nil
  }
  
  /// User/password callback
  func getPassword() async -> (String, String)?
  {
    guard passwordController == nil
    else {
      assertionFailure("already have a password sheet")
      return nil
    }
    let (window, controller) = DispatchQueue.main.sync {
      (windowController?.window, PasswordPanelController())
    }
    guard let window = window
    else { return nil }
    
    passwordController = controller
    return await controller.getPassword(parentWindow: window,
                                        host: host, path: path,
                                        port: UInt16(port))
  }
  
  func setKeychainInfo(from url: URL)
  {
    host = url.host ?? ""
    path = url.path
    port = url.port ?? url.defaultPort
  }
}
