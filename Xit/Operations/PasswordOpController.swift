import Cocoa

/// An operation that may require a password.
class PasswordOpController: SimpleOperationController
{
  let urlInfo: Box<(host: String, path: String, port: Int)> = .init(("", "", 80))
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
  nonisolated
  func getPassword() -> (String, String)?
  {
    guard !Thread.isMainThread
    else {
      assertionFailure("password callback on main thread")
      return nil
    }
    guard DispatchQueue.main.sync(execute: { passwordController == nil })
    else {
      assertionFailure("already have a password sheet")
      return nil
    }
    let (window, controller) = DispatchQueue.main.sync {
      let controller = PasswordPanelController()
      self.passwordController = controller
      return (windowController?.window, controller)
    }
    guard let window = window,
          let urlInfo = self.urlInfo.value
    else { return nil }
    
    return controller.getPassword(parentWindow: window,
                                  host: urlInfo.host,
                                  path: urlInfo.path,
                                  port: UInt16(urlInfo.port))
  }
  
  func setKeychainInfo(from url: URL)
  {
    urlInfo.value = (url.host ?? "", url.path, url.port ?? url.defaultPort)
  }
}
