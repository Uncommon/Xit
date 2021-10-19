import Cocoa

final class StashOperationController: SimpleOperationController
{
  override func start() throws
  {
    let panelController = StashPanelController.controller()
    
    windowController!.window!.beginSheet(panelController.window!) {
      (response) in
      if response == .OK {
        let message = panelController.message
        let keepIndex = panelController.keepStaged
        let includeUntracked = panelController.includeUntracked
        let includeIgnored = panelController.includeIgnored
        
        guard let repo = self.repository
        else { return }
        
        self.tryRepoOperation {
          try repo.saveStash(name: message,
                             keepIndex: keepIndex,
                             includeUntracked: includeUntracked,
                             includeIgnored: includeIgnored)
          self.ended()
        }
      }
      else {
        self.ended(result: .canceled)
      }
    }
  }
}
