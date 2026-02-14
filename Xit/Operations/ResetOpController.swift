import Foundation
import XitGit

final class ResetOpController: OperationController
{
  var targetCommit: (any Commit)!
  
  init(windowController: XTWindowController,
       targetCommit: any Commit)
  {
    self.targetCommit = targetCommit
    
    super.init(windowController: windowController)
  }
  
  override func start() throws
  {
    guard let window = windowController?.window,
          let repoController = windowController?.repoController,
          let repository = self.repository
    else { throw RepoError.unexpected }
    let panelController = ResetPanelController.controller()
    
    panelController.observe(repository: repository, controller: repoController)
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
    let targetCommit = self.targetCommit!

    tryRepoOperation {
      try repository.reset(toCommit: targetCommit, mode: mode)
      
      Task {
        @MainActor in
        // This doesn't get automatically sent because the index may have only
        // changed relative to the workspace.
        self.windowController?.repoController.indexChanged()
        self.ended()
      }
    }
  }
}
