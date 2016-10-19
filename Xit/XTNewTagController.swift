import Cocoa

class XTNewTagController: XTOperationController
{
  override func start()
  {
    let panelController = XTTagPanelController.controller()
    guard let selectedSHA = windowController?.selectedModel?.shaToSelect,
          let repository = repository,
          let commit = repository.commit(forSHA: selectedSHA)
    else { return }
    let config = repository.config
    let userName = config.userName()
    let userEmail = config.userEmail()
    
    panelController.commitMessage = commit.message ?? selectedSHA
    panelController.signature = "\(userName ?? "") <\(userEmail ?? "")>"
    windowController?.window?.beginSheet(panelController.window!) {
      (response) in
      if response == NSModalResponseOK {
        self.executeTag(name: panelController.tagName,
                        message: panelController.lightweight ?
                                 nil : panelController.message)
      }
      else {
        self.ended()
      }
    }
  }
  
  func executeTag(name: String, message: String?)
  {
    guard let repository = self.repository
    else { return }
    
    tryRepoOperation(successStatus: "Tag created",
                     failureStatus: "Tag failed") { 
      if let message = message {
        repository.createTag(name, withMessage: message)
      }
      else {
        repository.createLightweightTag(name)
      }
      NotificationCenter.default.post(
        name: NSNotification.Name.XTRepositoryRefsChanged, object: repository)
      self.ended()
    }
  }
}
