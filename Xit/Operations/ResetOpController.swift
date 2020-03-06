import Foundation

class ResetOpController: OperationController
{
  var targetCommit: Commit!
  
  init(windowController: XTWindowController,
       targetCommit: Commit)
  {
    self.targetCommit = targetCommit
    
    super.init(windowController: windowController)
  }
  
  override func start() throws
  {
    guard let window = windowController?.window,
          let repository = self.repository
    else { throw RepoError.unexpected }
    let panelController = ResetPanelController.controller()
    
    panelController.observe(repository: repository)
    window.beginSheet(panelController.window!) {
      (response) in
      if response == .OK {
        self.executeReset(mode: panelController.mode)
      }
      else {
        self.ended()
      }
    }
  }
  
  func executeReset(mode: ResetMode)
  {
    guard let repository = self.repository
    else { return }
    
    tryRepoOperation {
      try repository.reset(toCommit: self.targetCommit, mode: mode)
      
      // This doesn't get automatically sent because the index may have only
      // changed relative to the workspace.
      NotificationCenter.default.post(name: .XTRepositoryIndexChanged,
                                      object: repository)

      self.ended()
    }
  }
}
