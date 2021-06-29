import Cocoa

protocol TitleBarDelegate: AnyObject
{
  var viewStates: (sidebar: Bool, history: Bool, details: Bool) { get }

  func branchSelecetd(_ branch: String)
  func goBack()
  func goForward()
  func fetchSelected()
  func pushSelected()
  func pullSelected()
  func stashSelected()
  func popStashSelected()
  func applyStashSelected()
  func dropStashSelected()
  func showHideSidebar()
  func showHideHistory()
  func showHideDetails()
  func search()
}

extension Notification.Name
{
  static let XTProgress = Self("XTProgress")
}

extension Notification
{
  enum XTProgressKeys
  {
    static let progress = "progress"
    static let total = "total"
  }
  
  static func progressNotification(repository: AnyObject,
                                   progress: Float, total: Float) -> Notification
  {
    return Notification(name: .XTProgress,
                        object: repository,
                        userInfo: [XTProgressKeys.progress: progress,
                                   XTProgressKeys.total: total])
  }
  
  var progress: Float? { userInfo?[XTProgressKeys.progress] as? Float }
  var total: Float? { userInfo?[XTProgressKeys.total] as? Float }
}

class TitleBarController: NSObject
{
  @IBOutlet weak var window: NSWindow!
  @IBOutlet weak var navButtons: NSSegmentedControl!
  @IBOutlet weak var remoteControls: NSSegmentedControl!
  @IBOutlet weak var stashButton: NSSegmentedControl!
  @IBOutlet weak var spinner: NSProgressIndicator!
  @IBOutlet weak var branchPopup: NSPopUpButton!
  @IBOutlet weak var searchButton: NSButton!
  @IBOutlet weak var viewControls: NSSegmentedControl!
  @IBOutlet var stashMenu: NSMenu!
  @IBOutlet var fetchMenu: NSMenu!
  @IBOutlet var pushMenu: NSMenu!
  @IBOutlet var pullMenu: NSMenu!
  @IBOutlet var remoteOpsMenu: NSMenu!
  @IBOutlet var viewMenu: NSMenu!
  @IBOutlet var splitView: NSSplitView!

  weak var delegate: TitleBarDelegate?
  
  var progressObserver: NSObjectProtocol?
  var becomeKeyObserver: NSObjectProtocol?
  var resignKeyObserver: NSObjectProtocol?
  
  var separatorItem: NSToolbarItem?
  
  @objc dynamic var progressHidden: Bool
  {
    get
    { spinner.isHidden }
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
    case pull, push, fetch
  }
  
  enum ViewSegment: Int
  {
    case sidebar, history, details
  }
  
  func finishSetup()
  {
    let center = NotificationCenter.default
    
    if becomeKeyObserver == nil {
      becomeKeyObserver = center.addObserver(
          forName: NSWindow.didBecomeKeyNotification,
          object: window,
          queue: .main) {
        (_) in
      }
    }
    if resignKeyObserver == nil {
      resignKeyObserver = center.addObserver(
          forName: NSWindow.didResignKeyNotification,
          object: window,
          queue: .main) {
        (_) in
      }
    }
    
    remoteOpsMenu.items[0].submenu = pullMenu
    remoteOpsMenu.items[1].submenu = pushMenu
    remoteOpsMenu.items[2].submenu = fetchMenu
  }
  
  func observe(repository: XTRepository)
  {
    progressObserver = NotificationCenter.default.addObserver(
        forName: .XTProgress, object: repository, queue: .main) {
      [weak self] (notification) in
      guard let self = self,
            let progress = notification.progress,
            let total = notification.total
      else { return }
      
      self.spinner.isIndeterminate = false
      self.spinner.maxValue = Double(total)
      self.spinner.doubleValue = Double(progress)
      self.spinner.needsDisplay = true
    }
  }
  
  @IBAction
  func navigate(_ sender: Any?)
  {
    guard let control = sender as? NSSegmentedControl,
          let segment = NavSegment(rawValue: control.selectedSegment)
    else { return }
    
    switch segment {
      case .back:
        delegate?.goBack()
      case .forward:
        delegate?.goForward()
    }
  }
  
  @IBAction
  func remoteAction(_ sender: Any?)
  {
    guard let control = sender as? NSSegmentedControl,
          let segment = RemoteSegment(rawValue: control.selectedSegment)
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
  
  @IBAction
  func stash(_ sender: Any)
  {
    delegate?.stashSelected()
  }
  
  @IBAction
  func popStash(_ sender: Any)
  {
    delegate?.popStashSelected()
  }
  
  @IBAction
  func applyStash(_ sender: Any)
  {
    delegate?.applyStashSelected()
  }
  
  @IBAction
  func dropStash(_ sender: Any)
  {
    delegate?.dropStashSelected()
  }
  
  @IBAction
  func viewAction(_ sender: NSSegmentedControl)
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
    
    updateViewControls()
  }
  
  @IBAction func viewSidebar(_ sender: NSMenuItem)
  {
    delegate?.showHideSidebar()
  }
  
  @IBAction func viewHistory(_ sender: NSMenuItem)
  {
    delegate?.showHideHistory()
  }
  
  @IBAction func viewFiles(_ sender: NSMenuItem)
  {
    delegate?.showHideDetails()
  }

  func updateViewControls()
  {
    guard let states = delegate?.viewStates
    else { return }
    
    viewControls.setSelected(states.sidebar, forSegment: 0)
    viewControls.setSelected(states.history, forSegment: 1)
    viewControls.setSelected(states.details, forSegment: 2)
  }
  
  @IBAction
  func branchSelected(_ sender: NSPopUpButton)
  {
    guard let branch = branchPopup.titleOfSelectedItem
    else { return }
    
    delegate?.branchSelecetd(branch)
  }
  
  @IBAction
  func search(_ sender: Any)
  {
    delegate?.search()
  }
  
  var selectedBranch: String?
  {
    get { branchPopup.titleOfSelectedItem }
    set {
      DispatchQueue.main.async {
        [weak self] in
        self?.branchPopup.selectItem(withTitle: newValue ?? "")
      }
    }
  }
  
  func updateBranchList(_ branches: [String], current: String?)
  {
    branchPopup.removeAllItems()
    for branch in branches {
      let item = NSMenuItem(title: branch, action: nil, keyEquivalent: "")
      
      item.image = .xtBranch
      branchPopup.menu?.addItem(item)
    }
    if let current = current, branches.contains(current) {
      selectedBranch = current
    }
    else {
      let detachedItem = NSMenuItem(title: current ?? UIString.detached.rawValue,
                                    action: nil, keyEquivalent: "")
      
      detachedItem.isEnabled = false
      branchPopup.menu?.insertItem(detachedItem, at: 0)
      branchPopup.selectItem(at: 0)
    }
  }
}

extension NSToolbarItem.Identifier
{
  static let navigation: Self = ◊"xit.nav"
  static let spinner: Self = ◊"xit.spinner"
  static let branches: Self = ◊"xit.branches"
  static let remoteOps: Self = ◊"xit.remote"
  static let stash: Self = ◊"xit.stash"
  static let search: Self = ◊"xit.search"
  static let view: Self = ◊"xit.view"
}

extension TitleBarController: NSToolbarDelegate
{
  func toolbar(_ toolbar: NSToolbar,
               itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
               willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem?
  {
    if itemIdentifier == .sidebarTrackingSeparator {
      // Return the saved item to avoid Cocoa throwing exceptions about only
      // one tracking item being allowed.
      return separatorItem
    }
    return nil
  }
  
  func toolbarWillAddItem(_ notification: Notification)
  {
    guard let item = notification.userInfo?["item"] as? NSToolbarItem
    else { return }
    
    switch item.itemIdentifier {
      case .navigation:
        navButtons = item.view as? NSSegmentedControl
        
      case .spinner:
        spinner = item.view as? NSProgressIndicator
        
      case .branches:
        branchPopup = item.view as? NSPopUpButton

      case .remoteOps:
        remoteControls = item.view as? NSSegmentedControl
        
        let menuItem = NSMenuItem(title: item.label, action: nil,
                                  keyEquivalent: "")
        
        menuItem.submenu = remoteOpsMenu
        item.menuFormRepresentation = menuItem
        
      case .stash:
        let segmentMenus: [(NSMenu, TitleBarController.RemoteSegment)] = [
              (pullMenu, .pull),
              (pushMenu, .push),
              (fetchMenu, .fetch)]

        stashButton = item.view as? NSSegmentedControl
        for (menu, segment) in segmentMenus {
          remoteControls.setMenu(menu, forSegment: segment.rawValue)
        }
        stashButton.setMenu(stashMenu, forSegment: 0)

      case .search:
        searchButton = item.view as? NSButton
    
      case .view:
        viewControls = item.view as? NSSegmentedControl
        
        let menuItem = NSMenuItem(title: item.label, action: nil,
                                  keyEquivalent: "")
        
        menuItem.submenu = viewMenu
        item.menuFormRepresentation = menuItem
      
      case .sidebarTrackingSeparator:
        separatorItem = item
        
      default:
        return
    }
  }
}

extension TitleBarController: NSMenuItemValidation
{
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
  {
    if menuItem.menu?.identifier == ◊"branchMenu" {
      return true
    }
    
    guard let states = delegate?.viewStates
    else { return false }
    let state: Bool
    
    switch menuItem.action {
      case #selector(viewSidebar(_:)):
        state = states.sidebar
      case #selector(viewHistory(_:)):
        state = states.history
      case #selector(viewFiles(_:)):
        state = states.details
      default:
        return false
    }
    menuItem.state = state ? .on : .off
    return true
  }
}
