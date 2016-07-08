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
    
    let config = windowController!.xtDocument!.repository.config
    let sheetController = XTRemoteSheetController.controller()
    
    sheetController.resetFields()
    sheetController.name = remoteName
    sheetController.fetchURL = remote.URLString.flatMap({ NSURL(string: $0) })
    sheetController.pushURL = remote.pushURLString.flatMap({ NSURL(string: $0) })
    sheetController.selectedAccount = config.teamCityAccount(remoteName)
    windowController!.window?.beginSheet(sheetController.window!) {
        (response) in
      if response == NSModalResponseOK {
        self.acceptSheetSettings(sheetController)
      }
    }
  }
  
  func acceptSheetSettings(sheetController: XTRemoteSheetController)
  {
    let config = windowController!.xtDocument!.repository.config
    
    config.setTeamCityAccount(self.remoteName,
                              account: sheetController.selectedAccount)
    // remote.rename(sheetController.name)
    // remote.updateURLString(sheetController.fetchURL.absoluteString ?? ""
    // remote.updatePushURLString ... not available
    
    // If a rename was successful, us the new name here
    // (and delete the old setting)
    config.setTeamCityAccount(remoteName,
                              account: sheetController.selectedAccount)
    config.saveXitConfig()
  }
}
