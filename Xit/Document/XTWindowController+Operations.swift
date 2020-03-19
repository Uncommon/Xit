import Foundation

extension XTWindowController
{
  /// Returns the new operation, if any, mostly because the generic type must
  /// be part of the signature.
  @discardableResult
  func startOperation<OperationType: SimpleOperationController>()
      -> OperationType?
  {
    return startOperation { return OperationType(windowController: self) }
           as? OperationType
  }

  @discardableResult
  func startOperation(factory: () -> OperationController)
      -> OperationController?
  {
    if let operation = currentOperation {
      NSLog("Can't start new operation, already have \(operation)")
      return nil
    }
    else {
      let operation = factory()

      do {
        try operation.start()
        currentOperation = operation
        return operation
      }
      catch let error as RepoError {
        showErrorMessage(error: error)
        return nil
      }
      catch {
        showErrorMessage(error: RepoError.unexpected)
        return nil
      }
    }
  }

  func showErrorMessage(error: RepoError)
  {
    guard let window = self.window
    else { return }
    let alert = NSAlert()

    alert.messageString = error.message
    alert.beginSheetModal(for: window, completionHandler: nil)
  }

  /// Called by the operation controller when it's done.
  func operationEnded(_ operation: OperationController)
  {
    if currentOperation == operation {
      currentOperation = nil
    }
  }
}
