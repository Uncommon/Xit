import Cocoa

protocol XTTitleBarDelegate
{
  var viewStates: (sidebar: Bool, history: Bool, details: Bool) { get }

  func branchSelecetd(_ branch: String)
  func fetchSelected()
  func pushSelected()
  func pullSelected()
  func showHideSidebar()
  func showHideHistory()
  func showHideDetails()
}

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
  
  var delegate: XTTitleBarDelegate? = nil
  
  @IBAction func remoteAction(_ sender: NSSegmentedControl)
  {
    switch sender.selectedSegment {
      case 0:
        delegate?.fetchSelected()
      case 1:
        delegate?.pullSelected()
      case 2:
        delegate?.pushSelected()
      default:
        break
    }
  }
  
  @IBAction func viewAction(_ sender: NSSegmentedControl)
  {
    guard let delegate = self.delegate
    else { return }
    
    switch sender.selectedSegment {
      case 0:
        delegate.showHideSidebar()
      case 1:
        delegate.showHideHistory()
      case 2:
        delegate.showHideDetails()
      default:
        break
    }
    
    let states = delegate.viewStates
    
    viewControls.setSelected(states.sidebar, forSegment: 0)
    viewControls.setSelected(states.history, forSegment: 1)
    viewControls.setSelected(states.details, forSegment: 2)
  }
  
  @IBAction func branchSelected(_ sender: NSPopUpButton)
  {
    guard let branch = branchPopup.titleOfSelectedItem
    else { return }
    
    delegate?.branchSelecetd(branch)
  }
  
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
