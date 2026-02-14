import Cocoa
import XitGit

final class NewTagOpController: OperationController
{
  override func start() throws
  {
    guard let selectedOID = windowController?.selection?.target.oid,
          let repository = repository,
          let commit = repository.commit(forOID: selectedOID)
    else { throw RepoError.unexpected }
    let config = repository.config
    let userName = config.userName
    let userEmail = config.userEmail

    guard let window = windowController?.window
    else {
      self.ended()
      return
    }

    Task {
      let dialog = NewTagDialog(commitMessage: commit.message ??
                                               selectedOID.sha.rawValue,
                                signature: .init(name: userName,
                                                 email: userEmail,
                                                 when: .now))

      guard let options = await dialog.getOptions(parent: window)
      else {
        self.ended(result: .canceled)
        return
      }

      self.executeTag(name: options.tagName, oid: selectedOID,
                      message: options.tagType == .annotated ? options.message
                               : nil)
    }
  }
  
  func executeTag(name: String, oid: GitOID, message: String?)
  {
    guard let repository = self.repository
    else { return }
    
    tryRepoOperation { 
      if let message = message {
        try? repository.createTag(name: name, targetOID: oid, message: message)
      }
      else {
        try? repository.createLightweightTag(name: name, targetOID: oid)
      }
      self.refsChangedAndEnded()
    }
  }
}
