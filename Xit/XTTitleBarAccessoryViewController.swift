import Cocoa

class XTTitleBarAccessoryViewController: NSTitlebarAccessoryViewController {

  @IBOutlet weak var navigationControls: NSSegmentedControl!
  @IBOutlet weak var remoteControls: NSSegmentedControl!
  @IBOutlet weak var proxyIcon: NSImageView!
  @IBOutlet weak var spinner: NSProgressIndicator!
  @IBOutlet weak var titleLabel: NSTextField!
  @IBOutlet weak var branchLabel: NSTextField!
  @IBOutlet weak var operationButton: NSButton!
  @IBOutlet weak var operationControls: NSSegmentedControl!
  @IBOutlet weak var viewControls: NSSegmentedControl!
  
    
}
