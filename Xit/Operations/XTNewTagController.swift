import Cocoa

class XTNewTagController: XTOperationController
{
  override func start() throws
  {
    let panelController = XTTagPanelController.controller()
    guard let selectedSHA = windowController?.selection?.shaToSelect,
          let selectedOID = repository?.oid(forSHA: selectedSHA),
          let repository = repository,
          let commit = repository.commit(forSHA: selectedSHA)
    else { throw XTRepository.Error.unexpected }
    let config = repository.config!
    let userName = config.userName
    let userEmail = config.userEmail
    
    panelController.commitMessage = commit.message ?? selectedSHA
    panelController.signature = "\(userName ?? "") <\(userEmail ?? "")>"
    windowController?.window?.beginSheet(panelController.window!) {
      (response) in
      if response == .OK {
        self.executeTag(name: panelController.tagName,
                        oid: selectedOID,
                        message: panelController.lightweight ?
                                 nil : panelController.message)
      }
      else {
        self.ended()
      }
    }
  }
  
  func executeTag(name: String, oid: OID, message: String?)
  {
    guard let repository = self.repository
    else { return }
    
    tryRepoOperation(successStatus: "Tag created",
                     failureStatus: "Tag failed") { 
      if let message = message {
        try? repository.createTag(name: name, targetOID: oid, message: message)
      }
      else {
        try? repository.createLightweightTag(name: name, targetOID: oid)
      }
      NotificationCenter.default.post(name: .XTRepositoryRefsChanged,
                                      object: repository)
      self.ended()
    }
  }
}
