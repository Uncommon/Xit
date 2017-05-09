import Cocoa

protocol TitleBarDelegate: class
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

extension Notification.Name
{
  static let XTProgress = Notification.Name(rawValue: "XTProgress")
}

extension Notification
{
  struct XTProgressKeys
  {
    static let progress = "progress"
    static let total = "total"
  }
  
  static func progressNotification(repository: XTRepository,
                                   progress: Float, total: Float) -> Notification
  {
    return Notification(name: .XTProgress,
                        object: repository,
                        userInfo: [XTProgressKeys.progress: progress,
                                   XTProgressKeys.total: total])
  }
  
  var progress: Float? { return userInfo?[XTProgressKeys.progress] as? Float }
  var total: Float? { return userInfo?[XTProgressKeys.total] as? Float }
}

class TitleBarViewController: NSViewController
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
  
  weak var delegate: TitleBarDelegate?
  
  var progressObserver: NSObjectProtocol?
  
  dynamic var progressHidden: Bool
  {
    get
    {
      return spinner.isHidden
    }
    set
    {
      spinner.isIndeterminate = true
      spinner.isHidden = newValue
    }
  }
  
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
  
  deinit
  {
    progressObserver.map { NotificationCenter.default.removeObserver($0) }
  }
  
  override func viewDidLoad()
  {
    // This constraint will be active when the operations controls are shown.
    operationViewSpacing.isActive = false
  }
  
  func observe(repository: XTRepository)
  {
    progressObserver = NotificationCenter.default.addObserver(
        forName: .XTProgress, object: repository, queue: .main) {
      (notification) in
      guard let progress = notification.progress,
            let total = notification.total
      else { return }
      
      self.spinner.isIndeterminate = false
      self.spinner.maxValue = Double(total)
      self.spinner.doubleValue = Double(progress)
      self.spinner.needsDisplay = true
    }
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
