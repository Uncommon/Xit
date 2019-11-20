import Cocoa

class StashPanelController: SheetController
{
  @IBOutlet weak var messageField: NSTextField!
  @IBOutlet weak var keepStagedCheck: NSButton!
  @IBOutlet weak var untrackedCheck: NSButton!
  @IBOutlet weak var ignoredCheck: NSButton!
  
  @ControlStringValue var message: String
  @ControlBoolValue var keepStaged: Bool
  @ControlBoolValue var includeUntracked: Bool
  @ControlBoolValue var includeIgnored: Bool
  
  override func windowDidLoad()
  {
    super.windowDidLoad()
    
    $message = messageField
    $keepStaged = keepStagedCheck
    $includeUntracked = untrackedCheck
    $includeIgnored = ignoredCheck
  }
}
