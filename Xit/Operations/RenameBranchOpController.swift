import Cocoa

class RenameBranchOpController: OperationController
{
  let branchName: String
  
  init(windowController: XTWindowController, branchName: String)
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
        self.ended()
      }
    }
  }
  
  func executeRename(_ newName: String)
  {
    guard let repository = self.repository
    else { return }
    
    tryRepoOperation {
      try repository.rename(branch: self.branchName, to: newName)
      NotificationCenter.default.post(name: .XTRepositoryRefsChanged,
                                      object: repository)
      self.ended()
    }
  }
}
