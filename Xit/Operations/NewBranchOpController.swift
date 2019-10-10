import Foundation

class NewBranchOpController: OperationController
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
                           startPoint: panel.startingPoint)
      }
      else {
        self.ended(result: .canceled)
      }
    }
  }
  
  func executeBranch(name: String, startPoint: String)
  {
    do {
      _ = try windowController?.repository.createBranch(named: name,
                                                        target: startPoint)
    }
    catch let error as RepoError where error.isExpected {
      windowController?.showErrorMessage(error: error)
    }
    catch {
      windowController?.showErrorMessage(error: .unexpected)
    }
  }
}
