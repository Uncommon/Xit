import Cocoa

class RemoteOptionsOpController: OperationController
{
  let remoteName: String
  
  init(windowController: XTWindowController, remote: String)
  {
    self.remoteName = remote
    
    super.init(windowController: windowController)
  }
  
  override func start() throws
  {
    guard let repository = repository,
          let remote = repository.remote(named: remoteName)
    else { throw XTRepository.Error.unexpected }
    
    let sheetController = RemoteSheetController.controller()
    
    sheetController.resetFields()
    sheetController.name = remoteName
    sheetController.fetchURL = remote.urlString.flatMap { URL(string: $0) }
    sheetController.pushURL = remote.pushURLString.flatMap { URL(string: $0) }
    windowController!.window?.beginSheet(sheetController.window!) {
      (response) in
      var result: Result
      if response == .OK {
        self.acceptSheetSettings(sheetController)
        result = .success
      }
      else {
        result = .canceled
      }
      self.ended(result: result)
    }
  }
  
  func acceptSheetSettings(_ sheetController: RemoteSheetController)
  {
    // update name and URLs if changed
  }
}
