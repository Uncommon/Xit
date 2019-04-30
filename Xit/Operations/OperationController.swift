import Cocoa

/// Takes charge of executing a command
class OperationController: NSObject
{
  enum Result
  {
    case success
    case failure
    case canceled
  }
  
  /// The window controller that initiated and owns the operation. May be nil
  /// if the window is closed before the operation completes.
  weak var windowController: XTWindowController?
  /// Convenient reference to the repository from the window controller.
  weak var repository: XTRepository?
  /// True if the operation is being canceled.
  var canceled = false
  /// Actions to be executed after the operation succeeds.
  var successActions: [() -> Void] = []
  
  init(windowController: XTWindowController)
  {
    self.windowController = windowController
    self.repository = windowController.xtDocument!.repository
  }
  
  /// Initiates the operation.
  func start() throws {}
  
  @objc
  func abort() {}
  
  func ended(result: Result = .success)
  {
    if result == .success {
      for action in successActions {
        action()
      }
    }
    successActions.removeAll()
    windowController?.operationEnded(self)
  }
  
  func onSuccess(_ action: @escaping () -> Void)
  {
    successActions.append(action)
  }
  
  /// Override to suppress errors.
  func shoudReport(error: NSError) -> Bool { return true }
  
  /// Executes the given block, handling errors and updating status.
  func tryRepoOperation(block: @escaping (() throws -> Void))
  {
    repository?.queue.executeOffMainThread {
      [weak self] in
      do {
        try block()
      }
      catch _ as RepoError {
        // The command shouldn't have been enabled if this was going to happen
        self?.ended(result: .failure)
      }
      catch let error as NSError {
        defer {
          self?.ended(result: .failure)
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
            alert.beginSheetModal(for: window) {
              _ in self?.ended(result: .failure)
            }
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
