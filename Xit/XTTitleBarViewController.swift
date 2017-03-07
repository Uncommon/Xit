import Cocoa

protocol XTTitleBarDelegate: class
{
  var viewStates: (sidebar: Bool, history: Bool, details: Bool) { get }

  func branchSelecetd(_ branch: String)
  func goBack()
  func goForward()
  func fetchSelected()
  func pushSelected()
  func pullSelected()
  func showHideSidebar()
  func showHideHistory()
  func showHideDetails()
}

class XTTitleBarViewController: NSViewController
{
  @IBOutlet weak var navButtons: NSSegmentedControl!
  @IBOutlet weak var remoteControls: NSSegmentedControl!
  @IBOutlet weak var proxyIcon: NSImageView!
  @IBOutlet weak var spinner: NSProgressIndicator!
  @IBOutlet weak var titleLabel: NSTextField!
  @IBOutlet weak var branchPopup: NSPopUpButton!
  @IBOutlet weak var operationButton: NSButton!
  @IBOutlet weak var operationControls: NSSegmentedControl!
  @IBOutlet weak var viewControls: NSSegmentedControl!
  @IBOutlet weak var operationViewSpacing: NSLayoutConstraint!
  
  weak var delegate: XTTitleBarDelegate? = nil
  
  enum NavSegment: Int
  {
    case back, forward
  }
  
  enum RemoteSegment: Int
  {
    case fetch, pull, push
  }
  
  enum ViewSegment: Int
  {
    case sidebar, history, details
  }
  
  override func viewDidLoad()
  {
    // This constraint will be active when the operations controls are shown.
    operationViewSpacing.isActive = false
  }
  
  @IBAction func navigate(_ sender: NSSegmentedControl)
  {
    guard let segment = NavSegment(rawValue: sender.selectedSegment)
    else { return }
    
    switch segment {
      case .back:
        delegate?.goBack()
      case .forward:
        delegate?.goForward()
    }
  }
  
  @IBAction func remoteAction(_ sender: NSSegmentedControl)
  {
    guard let segment = RemoteSegment(rawValue: sender.selectedSegment)
    else { return }
    
    switch segment {
      case .fetch:
        delegate?.fetchSelected()
      case .pull:
        delegate?.pullSelected()
      case .push:
        delegate?.pushSelected()
    }
  }
  
  @IBAction func viewAction(_ sender: NSSegmentedControl)
  {
    guard let segment = ViewSegment(rawValue: sender.selectedSegment),
          let delegate = self.delegate
    else { return }
    
    switch segment {
      case .sidebar:
        delegate.showHideSidebar()
      case .history:
        delegate.showHideHistory()
      case .details:
        delegate.showHideDetails()
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
  
  func updateBranchList(_ branches: [String], current: String?)
  {
    branchPopup.removeAllItems()
    branchPopup.addItems(withTitles: branches)
    if let current = current {
      selectedBranch = current
    }
  }
}
