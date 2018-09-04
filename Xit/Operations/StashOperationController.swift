import Cocoa

class StashOperationController: OperationController
{
  override func start() throws
  {
    let panelController = StashPanelController.controller()
    
    windowController!.window!.beginSheet(panelController.window!) {
      (response) in
      if response == .OK {
        // stash
      }
      self.ended()
    }
  }
}
