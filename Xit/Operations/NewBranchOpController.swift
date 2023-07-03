import Foundation

final class NewBranchOpController: OperationController
{
  override func start() throws
  {
    guard let repository = repository
    else { throw RepoError.unexpected }
    
    let panel = NewBranchPanelController.controller()
    
    panel.configure(branchName: "",
                    startingPoint: repository.currentBranch ?? "",
                    repository: repository)
    windowController!.window!.beginSheet(panel.window!) {
      (response) in
      if response == NSApplication.ModalResponse.OK {
        self.executeBranch(name: panel.branchName,
                           startPoint: panel.startingPoint,
                           track: panel.trackStartingPoint,
                           checkOut: panel.checkOutBranch)
      }
      else {
        self.ended(result: .canceled)
      }
    }
  }
  
  func executeBranch(name: String, startPoint: String,
                     track: Bool, checkOut: Bool)
  {
    do {
      guard let repository
      else { throw RepoError.unexpected }
      
      let operation = NewBranchOperation(repository: repository)
      let parameters = NewBranchOperation.Parameters(
        name: name, startPoint: startPoint, track: track, checkOut: checkOut)
      
      try operation.perform(using: parameters)
    }
    catch let error as RepoError where error.isExpected {
      windowController?.showErrorMessage(error: error)
    }
    catch {
      windowController?.showErrorMessage(error: .unexpected)
    }
  }
}
