import Cocoa

protocol XTTitleBarDelegate
{
  func branchSelecetd(_ branch: String)
  func fetchSelecetd()
  func pushSelecetd()
  func pullSelecetd()
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
        delegate?.fetchSelecetd()
      case 1:
        delegate?.pullSelecetd()
      case 2:
        delegate?.pushSelecetd()
      default:
        break
    }
  }
  
  @IBAction func viewAction(_ sender: NSSegmentedControl)
  {
    switch sender.selectedSegment {
    case 0:
      delegate?.showHideSidebar()
    case 1:
      delegate?.showHideHistory()
    case 2:
      delegate?.showHideDetails()
    default:
      break
    }
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
