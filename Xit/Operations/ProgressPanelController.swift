import Cocoa
import SwiftUI

class ProgressPanelController: NSWindowController
{
  let model: ObservableProgress
  
  init(model: ObservableProgress, stopAction: @escaping () -> Void)
  {
    let panel = ProgressPanel(model: model,
                              stopAction: stopAction)
    let viewController = NSHostingController(rootView: panel)
    let window = NSWindow(contentViewController: viewController)
    
    self.model = model
    
    super.init(window: window)
    
    // Assuming this will be a sheet, no more configuration is needed.
  }
  
  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
}
