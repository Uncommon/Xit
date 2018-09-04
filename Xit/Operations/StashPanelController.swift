import Cocoa

class StashPanelController: SheetController
{
  @IBOutlet weak var stashAllRadio: NSButton!
  @IBOutlet weak var stashWorkspaceRadio: NSButton!
  @IBOutlet weak var untrackedCheck: NSButton!
  @IBOutlet weak var ignoredCheck: NSButton!
  
  /// Tag values for the radio buttons
  enum StashType: Int
  {
    case all = 0
    case workspaceOnly = 1
  }
  
  var type: StashType
  {
    get
    {
      return stashAllRadio.boolValue ? .all : .workspaceOnly
    }
    set
    {
      stashAllRadio.boolValue = newValue == .all
      stashWorkspaceRadio.boolValue = newValue == .workspaceOnly
    }
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
  
  @IBAction func stashRadioClicked(_ sender: Any)
  {
  }
}
