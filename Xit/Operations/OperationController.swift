import Cocoa

/// Takes charge of executing a command
class OperationController: NSObject
{
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
  func start() throws {}
  
  func ended()
  {
    windowController?.operationEnded(self)
  }
  
  /// Override to suppress errors.
  func shoudReport(error: NSError) -> Bool { return true }
  
  /// Executes the given block, handling errors and updating status.
  func tryRepoOperation(successStatus: String,
                        failureStatus: String,
                        block: @escaping (() throws -> Void))
  {
    repository?.queue.executeOffMainThread {
      [weak self] in
      do {
        try block()
      }
      catch _ as XTRepository.Error {
        // The command shouldn't have been enabled if this was going to happen
      }
      catch let error as NSError {
        defer {
          self?.ended()
        }
        guard self?.shoudReport(error: error) ?? false
        else { return }
        let gitError = giterr_last()
        
        DispatchQueue.main.async {
          [weak self] in
          if let window = self?.windowController?.window {
            let alert = NSAlert(error: error)
            
            if let error = gitError {
              let errorString = String(cString: error.pointee.message)
              let message = alert.messageText + " (\(errorString))"
              
              alert.messageText = message
            }
            
            // needs to be smarter: look at error type
            alert.beginSheetModal(for: window,
                                  completionHandler: { _ in self?.ended() })
          }
        }
      }
    }
  }
}


/// For simple operations that won't need to be initialized with more parameters.
class SimpleOperationController: OperationController
{
  required override init(windowController: XTWindowController)
  {
    super.init(windowController: windowController)
  }
}
