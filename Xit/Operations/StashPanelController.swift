import Cocoa

class StashPanelController: SheetController
{
  @IBOutlet weak var messageField: NSTextField!
  @IBOutlet weak var keepStagedCheck: NSButton!
  @IBOutlet weak var untrackedCheck: NSButton!
  @IBOutlet weak var ignoredCheck: NSButton!
  
  var message: String
  {
    get { return messageField.stringValue }
    set { messageField.stringValue = newValue }
  }
  
  var keepStaged: Bool
  {
    get { return keepStagedCheck.boolValue }
    set { keepStagedCheck.boolValue = newValue }
  }

  var includeUntracked: Bool
  {
    get { return untrackedCheck.boolValue }
    set { untrackedCheck.boolValue = newValue }
  }
  
  var includeIgnored: Bool
  {
    get { return ignoredCheck.boolValue }
    set { ignoredCheck.boolValue = newValue }
  }
}
