import Cocoa

/// Takes charge of executing a command
class OperationController
{
  enum OperationResult
  {
    case success
    case failure
    case canceled
  }
  
  /// The window controller that initiated and owns the operation. May be nil
  /// if the window is closed before the operation completes.
  weak var windowController: XTWindowController?
  /// Convenient reference to the repository from the window controller.
  weak var repository: Repository?
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
  
  func abort() {}
  
  func ended(result: OperationResult = .success)
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
  
  func repoErrorMessage(for error: RepoError) -> UIString
  {
    return error.message
  }
  
  /// Executes the given block on the repository queue, handling errors and
  /// updating status.
  func tryRepoOperation(block: @escaping (() throws -> Void))
  {
    windowController?.repoController.queue.executeOffMainThread {
      [weak self] in
      do {
        try block()
      }
      catch let error {
        guard let self = self
        else { return }
        
        defer {
          self.ended(result: .failure)
        }
        
        switch error {
          
          case let repoError as RepoError:
            self.showFailureError(self.repoErrorMessage(for: repoError).rawValue)
          
          case let nsError as NSError where self.shoudReport(error: nsError):
            var message = error.localizedDescription
            
            if let gitError = git_error_last() {
              let errorString = String(cString: gitError.pointee.message)
              
              message.append(" \(errorString)")
            }
            self.showFailureError(message)
          
          default:
            break
        }
      }
    }
  }
  
  func showFailureError(_ message: String)
  {
    DispatchQueue.main.async {
      if let window = self.windowController?.window {
        let alert = NSAlert()
        
        alert.messageText = message
        alert.beginSheetModal(for: window, completionHandler: nil)
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
