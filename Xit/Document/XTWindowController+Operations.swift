import Foundation
import Cocoa

enum RemoteOperationOption
{
  case all, new, currentBranch, named(String)
}

extension XTWindowController
{
  /// Returns the new operation, if any, mostly because the generic type must
  /// be part of the signature.
  @discardableResult
  func startOperation<OperationType: SimpleOperationController>()
      -> OperationType?
  {
    return startOperation { OperationType(windowController: self) }
           as? OperationType
  }

  // TODO: factory usually references this controller, so pass it in
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

  func showAlert(message: UIString, info: UIString)
  {
    guard let window = self.window
    else { return }
    let alert = NSAlert()

    alert.messageString = message
    alert.informativeString = info
    alert.beginSheetModal(for: window)
  }

  func showAlert(nsError: NSError)
  {
    guard let window = self.window
    else { return }
    let alert = NSAlert(error: nsError)

    alert.beginSheetModal(for: window)
  }

  /// Called by the operation controller when it's done.
  func operationEnded(_ operation: OperationController)
  {
    if currentOperation === operation {
      currentOperation = nil
    }
  }
}
