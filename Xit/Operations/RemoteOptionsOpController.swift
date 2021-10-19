import Cocoa

final class RemoteOptionsOpController: OperationController
{
  let remoteName: String
  let sheetController = RemoteSheetController.controller()
  
  init(windowController: XTWindowController, remote: String)
  {
    self.remoteName = remote
    
    super.init(windowController: windowController)
  }
  
  override func start() throws
  {
    guard let repository = repository,
          let remote = repository.remote(named: remoteName)
    else { throw RepoError.unexpected }
    
    sheetController.delegate = self
    sheetController.resetFields()
    sheetController.name = remoteName
    sheetController.fetchURLString = remote.urlString
    sheetController.pushURLString = remote.pushURLString
    windowController!.window?.beginSheet(sheetController.window!) {
      (response) in
      self.ended(result: (response == .OK) ? .success : .canceled)
    }
  }
}

extension RemoteOptionsOpController: RemoteSheetDelegate
{
  func acceptSettings(from sheetController: RemoteSheetController) -> Bool
  {
    guard let remote = windowController?.repository.remote(named: remoteName)
    else { return false }
    var errorMessage: UIString?
    
    do {
      if remote.name != sheetController.name {
        try remote.rename(sheetController.name)
      }
      
      let newURL = sheetController.fetchURLString
      let newPushURL = sheetController.pushURLString
      
      if remote.urlString != newURL {
        try remote.updateURLString(newURL)
      }
      if remote.pushURLString != newPushURL {
        try remote.updatePushURLString(newPushURL)
      }
    }
    catch let error as RepoError {
      errorMessage = error.message
    }
    catch {
      errorMessage = RepoError.unexpected.message
    }

    if let message = errorMessage {
      NSAlert.showMessage(window: windowController?.window, message: message)
      return false
    }
    else {
      return true
    }
  }
}
