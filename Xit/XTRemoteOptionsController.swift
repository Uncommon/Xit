import Cocoa

class XTRemoteOptionsController: XTOperationController
{
  let remoteName: String
  
  init(windowController: XTWindowController, remote: String)
  {
    self.remoteName = remote
    
    super.init(windowController: windowController)
  }
  
  func start()
  {
    guard let remote = try? GTRemote(name: remoteName,
                                     inRepository: repository.gtRepo)
    else { return }
    
    let sheetController = XTRemoteSheetController.controller()
    
    sheetController.resetFields()
    sheetController.name = remoteName
    sheetController.fetchURL = remote.URLString.flatMap({ NSURL(string: $0) })
    sheetController.pushURL = remote.pushURLString.flatMap({ NSURL(string: $0) })
    windowController!.window?.beginSheet(sheetController.window!) {
        (response) in
      if response == NSModalResponseOK {
        self.acceptSheetSettings(sheetController)
      }
    }
  }
  
  func acceptSheetSettings(sheetController: XTRemoteSheetController)
  {
    // update name and URLs if changed
  }
}
