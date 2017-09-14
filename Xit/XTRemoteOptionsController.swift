import Cocoa

class XTRemoteOptionsController: XTOperationController
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
          let remote = try? GTRemote(name: remoteName,
                                     in: repository.gtRepo)
    else { throw XTRepository.Error.unexpected }
    
    let sheetController = XTRemoteSheetController.controller()
    
    sheetController.resetFields()
    sheetController.name = remoteName
    sheetController.fetchURL = remote.urlString.flatMap({ URL(string: $0) })
    sheetController.pushURL = remote.pushURLString.flatMap({ URL(string: $0) })
    windowController!.window?.beginSheet(sheetController.window!) {
      (response) in
      if response == NSModalResponseOK {
        self.acceptSheetSettings(sheetController)
      }
    }
  }
  
  func acceptSheetSettings(_ sheetController: XTRemoteSheetController)
  {
    // update name and URLs if changed
  }
}
