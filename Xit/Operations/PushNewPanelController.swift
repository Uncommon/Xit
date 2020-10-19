import Cocoa

class PushNewPanelController: SheetController
{
  @IBOutlet weak var remotePopup: NSPopUpButton!
  @IBOutlet weak var setTrackingCheck: NSButton!
  @IBOutlet weak var alreadyTrackingWarning: NSStackView!
  
  @ControlBoolValue
  var setTrackingBranch: Bool
  
  var alreadyTracking: Bool
  {
    get { !alreadyTrackingWarning.isHidden }
    set { alreadyTrackingWarning.isHidden = !newValue }
  }
  
  var selectedRemote: String
  { remotePopup.selectedItem?.title ?? "" }
  
  override func windowDidLoad()
  {
    super.windowDidLoad()

    $setTrackingBranch = setTrackingCheck
  }
  
  override func resetFields()
  {
    setTrackingBranch = true
  }
  
  func setRemotes(_ remotes: [String])
  {
    remotePopup.removeAllItems()
    remotePopup.addItems(withTitles: remotes)
    
    if let originIndex = remotes.firstIndex(of: "origin") {
      remotePopup.selectItem(at: originIndex)
    }
  }
}
