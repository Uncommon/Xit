import Cocoa

class XTTitleBarAccessoryViewController: NSViewController
{
  @IBOutlet weak var remoteControls: NSSegmentedControl!
  @IBOutlet weak var proxyIcon: NSImageView!
  @IBOutlet weak var spinner: NSProgressIndicator!
  @IBOutlet weak var titleLabel: NSTextField!
  @IBOutlet weak var branchPopup: NSPopUpButton!
  @IBOutlet weak var operationButton: NSButton!
  @IBOutlet weak var operationControls: NSSegmentedControl!
  @IBOutlet weak var viewControls: NSSegmentedControl!
  
  var selectedBranch: String?
  {
    get { return branchPopup.titleOfSelectedItem }
    set { branchPopup.selectItem(withTitle: newValue ?? "") }
  }
  
  func updateBranchList(_ branches: [String])
  {
    let savedBranch = selectedBranch
    
    branchPopup.removeAllItems()
    branchPopup.addItems(withTitles: branches)
    selectedBranch = savedBranch
  }
}
