import Cocoa

final class RenameBranchOpController: OperationController
{
  let branchName: LocalBranchRefName

  init(windowController: XTWindowController, branchName: LocalBranchRefName)
  {
    self.branchName = branchName
    
    super.init(windowController: windowController)
  }
  
  override func start() throws
  {
    let panelController = RenameBranchPanelController.controller()
    
    panelController.branchName = branchName
    windowController?.window?.beginSheet(panelController.window!) {
      (response) in
      if response == .OK {
        self.executeRename(panelController.textField.stringValue)
      }
      else {
        self.ended(result: .canceled)
      }
    }
  }
  
  func executeRename(_ newName: String)
  {
    guard let repository = self.repository,
          let newName = LocalBranchRefName.named(newName)
    else { return }
    
    tryRepoOperation {
      try repository.rename(branch: self.branchName, to: newName)
      self.refsChangedAndEnded()
    }
  }
}
