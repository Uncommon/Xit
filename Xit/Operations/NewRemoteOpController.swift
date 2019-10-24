import Foundation

/// Operation for adding a new remote
class NewRemoteOpController: OperationController
{
  let sheetController = RemoteSheetController.controller()

  override init(windowController: XTWindowController)
  {
    super.init(windowController: windowController)
    
    sheetController.setMode(.create(.createRemote))
    sheetController.delegate = self
  }
  
  override func start() throws
  {
    sheetController.resetFields()
    windowController!.window?.beginSheet(sheetController.window!) {
      (response) in
      self.ended(result: (response == .OK) ? .success : .canceled)
    }
  }
}

extension NewRemoteOpController: RemoteSheetDelegate
{
  func acceptSettings(from sheetController: RemoteSheetController) -> Bool
  {
    guard let repository = windowController?.repository,
          let fetchURL = sheetController.fetchURLString
                                        .flatMap({ URL(string: $0) })
    else { return false }
    
    if let pushURLString = sheetController.pushURLString,
       URL(string: pushURLString) == nil {
      return false
    }
    
    do {
      let remoteName = sheetController.name
      
      try repository.addRemote(named: remoteName, url: fetchURL)
      if let pushURLString = sheetController.pushURLString,
         let remote = repository.remote(named: remoteName) {
        try remote.updatePushURLString(pushURLString)
      }

      return true
    }
    catch let error as RepoError {
      windowController?.showErrorMessage(error: error)
    }
    catch {
      windowController?.showErrorMessage(error: .unexpected)
    }
    return false
  }
}
