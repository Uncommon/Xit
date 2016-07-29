import Cocoa

/// Takes charge of executing a command
class XTOperationController: NSObject {
  
  /// The window controller that initiated and owns the operation. May be nil
  /// if the window is closed before the operation completes.
  weak var windowController: XTWindowController?
  /// Convenient reference to the repository from the window controller.
  let repository: XTRepository
  /// True if the operation is being canceled.
  var canceled = false
  
  init(windowController: XTWindowController)
  {
    self.windowController = windowController
    self.repository = windowController.xtDocument!.repository
  }
  
  /// Initiates the operation.
  func start() {}
}


/// For simple operations that won't need to be initialized with more parameters.
class XTSimpleOperationController: XTOperationController {
  required override init(windowController: XTWindowController)
  {
    super.init(windowController: windowController)
  }
}
