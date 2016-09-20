import Cocoa

/// Takes charge of executing a command
class XTOperationController: NSObject {
  
  /// The window controller that initiated and owns the operation. May be nil
  /// if the window is closed before the operation completes.
  weak var windowController: XTWindowController?
  /// Convenient reference to the repository from the window controller.
  weak var repository: XTRepository?
  /// True if the operation is being canceled.
  var canceled = false
  
  init(windowController: XTWindowController)
  {
    self.windowController = windowController
    self.repository = windowController.xtDocument!.repository
  }
  
  /// Initiates the operation.
  func start() {}
  
  func ended()
  {
    self.windowController?.operationEnded(self)
  }
  
  /// Executes the given block, handling errors and updating status.
  func tryRepoOperation(successStatus: String,
                        failureStatus: String,
                        block: @escaping (() throws -> Void))
  {
    repository?.executeOffMainThread {
      do {
        try block()
      }
      catch _ as XTRepository.Error {
        // The command shouldn't have been enabled if this was going to happen
      }
      catch let error as NSError {
        DispatchQueue.main.async {
          if let window = self.windowController?.window {
            let alert = NSAlert(error: error)
            
            // needs to be smarter: look at error type
            alert.beginSheetModal(for: window, completionHandler: nil)
          }
        }
      }
    }
  }
}


/// For simple operations that won't need to be initialized with more parameters.
class XTSimpleOperationController: XTOperationController {
  required override init(windowController: XTWindowController)
  {
    super.init(windowController: windowController)
  }
}
