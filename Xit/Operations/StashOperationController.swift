import Cocoa

class StashOperationController: SimpleOperationController
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
        
        self.tryRepoOperation(successStatus: "Stash completed",
                              failureStatus: "Stash failed") {
          try repo.saveStash(name: message,
                             keepIndex: keepIndex,
                             includeUntracked: includeUntracked,
                             includeIgnored: includeIgnored)
        }
      }
      self.ended()
    }
  }
}
