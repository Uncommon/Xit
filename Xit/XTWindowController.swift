import Cocoa

/// XTDocument's main window controller.
class XTWindowController: NSWindowController, NSWindowDelegate
{
  @IBOutlet var historyController: XTHistoryViewController!
  @IBOutlet var activity: NSProgressIndicator!
  weak var xtDocument: XTDocument?
  var titleBarController: XTTitleBarAccessoryViewController? = nil
  var selectedCommitSHA: String?
  dynamic var selectedModel: XTFileChangesModel?
  {
    didSet
    {
      var userInfo = [AnyHashable: Any]()
      
      userInfo[NSKeyValueChangeKey.newKey] = selectedModel
      userInfo[NSKeyValueChangeKey.oldKey] = oldValue
      
      NotificationCenter.default.post(
          name: NSNotification.Name.XTSelectedModelChanged,
          object: self,
          userInfo: userInfo)
    }
  }
  var inStagingView: Bool { return self.selectedCommitSHA == XTStagingSHA }
  
  var currentOperation: XTOperationController?
  
  override var document: AnyObject? {
    didSet {
      xtDocument = document as! XTDocument?
    }
  }
  
  override func windowDidLoad()
  {
    super.windowDidLoad()
    
    let window = self.window!
    
    window.titleVisibility = .hidden
    window.delegate = self
    // We could set the window's contentViewController, but then it would
    // retain the view controller, which is undesirable.
    window.contentView = historyController.view
    window.makeFirstResponder(historyController.historyTable)
    
    let repo = xtDocument!.repository!
    
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(XTWindowController.taskStarted(_:)),
        name: NSNotification.Name.XTTaskStarted,
        object: repo)
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(XTWindowController.taskEnded(_:)),
        name: NSNotification.Name.XTTaskEnded,
        object: repo)
    NotificationCenter.default.addObserver(
        forName: NSNotification.Name.XTRepositoryRefsChanged,
        object: repo, queue: nil) {
      (notification) in
      self.updateBranchList()
    }
    repo.addObserver(self, forKeyPath: #keyPath(XTRepository.currentBranch),
                     options: [], context: nil)
    historyController.windowDidLoad()
    historyController.setRepo(repo)
  }
  
  deinit
  {
    NotificationCenter.default.removeObserver(self)
    currentOperation?.canceled = true
  }
  
  override func observeValue(forKeyPath keyPath: String?,
                             of object: Any?,
                             change: [NSKeyValueChangeKey : Any]?,
                             context: UnsafeMutableRawPointer?)
  {
    if let repo = object as? XTRepository,
       keyPath == #keyPath(XTRepository.currentBranch) {
      titleBarController?.selectedBranch = repo.currentBranch
    }
  }
  
  func updateBranchList()
  {
    guard let repo = xtDocument?.repository,
          let branches = try? repo.localBranches()
    else { return }
    
    self.titleBarController?.updateBranchList(branches.flatMap { $0.shortName })
  }
  
  func taskStarted(_ notification: Notification)
  {
  }
  
  func taskEnded(_ notification: Notification)
  {
  }
  
  @IBAction func refresh(_ sender: AnyObject)
  {
    historyController.reload()
  }
  
  @IBAction func showHideSidebar(_ sender: AnyObject)
  {
    historyController.toggleSideBar(sender)
    titleBarController!.viewControls.setSelected(
        !historyController.sideBarHidden(), forSegment: 0)
  }
  
  @IBAction func showHideHistory(_ sender: AnyObject)
  {
    historyController.toggleHistory(sender)
  }
  
  @IBAction func showHideDetails(_ sender: AnyObject)
  {
    historyController.toggleDetails(sender)
  }
  
  @IBAction func verticalLayout(_ sender: AnyObject)
  {
    self.historyController.mainSplitView.isVertical = true
    self.historyController.mainSplitView.adjustSubviews()
  }
  
  @IBAction func horizontalLayout(_ sender: AnyObject)
  {
    self.historyController.mainSplitView.isVertical = false
    self.historyController.mainSplitView.adjustSubviews()
  }
  
  @IBAction func newTag(_: AnyObject) {}
  @IBAction func newBranch(_: AnyObject) {}
  @IBAction func addRemote(_: AnyObject) {}

  @IBAction func fetch(_: AnyObject)
  {
    let _: XTFetchController? = startOperation()
  }
  
  @IBAction func pull(_: AnyObject)
  {
    let _: XTPullController? = startOperation()
  }
  
  @IBAction func push(_: AnyObject)
  {
    let _: XTPushController? = startOperation()
  }
  
  /// Returns the new operation, if any, mostly because the generic type must
  /// be part of the signature.
  func startOperation<OperationType: XTSimpleOperationController>()
      -> OperationType?
  {
    if currentOperation == nil {
      let operation = OperationType(windowController: self)
      
      operation.start()
      currentOperation = operation
      return operation
    }
    else {
      NSLog("Can't start new operation, already have \(currentOperation)")
    }
    return nil
  }
  
  @IBAction func viewSegmentClicked(_ sender: AnyObject)
  {
    switch (sender as! NSSegmentedControl).selectedSegment {
      case 0:
        showHideSidebar(sender)
      default:
        break
    }
  }
  
  /// Called by the operation controller when it's done.
  func operationEnded(_ operation: XTOperationController)
  {
    if currentOperation == operation {
      currentOperation = nil
    }
  }
  
  @IBAction func remoteSettings(_ sender: AnyObject)
  {
    guard let menuItem = sender as? NSMenuItem
    else { return }
    
    let controller = XTRemoteOptionsController(windowController: self,
                                               remote: menuItem.title)
  
    controller.start()
  }
  
  func updateRemotesMenu(_ menu: NSMenu) {
    let remoteNames = xtDocument!.repository.remoteNames
    
    menu.removeAllItems()
    for name in remoteNames {
      menu.addItem(NSMenuItem(title: name,
                              action: #selector(self.remoteSettings(_:)),
                              keyEquivalent: ""))
    }
  }
  
  override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
  {
    guard let action = menuItem.action
    else { return false }
    var result = false
    
    switch action {

      case #selector(self.refresh(_:)):
        result = !xtDocument!.repository.isWriting

      case #selector(self.showHideSidebar(_:)):
        result = true
        if historyController.sidebarSplitView.isSubviewCollapsed(
            historyController.sidebarSplitView.subviews[0]) {
          menuItem.title = NSLocalizedString("Show Sidebar", comment: "")
        }
        else {
          menuItem.title = NSLocalizedString("Hide Sidebar", comment: "")
        }

      case #selector(self.verticalLayout(_:)):
        result = true
        menuItem.state = historyController.mainSplitView.isVertical
            ? NSOnState : NSOffState

      case #selector(self.horizontalLayout(_:)):
        result = true
        menuItem.state = historyController.mainSplitView.isVertical
            ? NSOffState : NSOnState

      case #selector(self.remoteSettings(_:)):
        result = true

      default:
        result = false
    }
    return result
  }
}

extension XTWindowController: XTTitleBarDelegate
{
  func branchSelecetd(_ branch: String)
  {
    try? xtDocument!.repository!.checkout(branch)
  }
  
  var viewStates: (sidebar: Bool, history: Bool, details: Bool)
  {
    return (!historyController.sideBarHidden(),
            !historyController.historyHidden(),
            !historyController.detailsHidden())
  }
  
  func fetchSelecetd() { fetch(self) }
  func pushSelecetd() { push(self) }
  func pullSelecetd() { pull(self) }
  func showHideSidebar() { showHideSidebar(self) }
  func showHideHistory() { showHideHistory(self) }
  func showHideDetails() { showHideDetails(self) }
}

extension XTWindowController: NSToolbarDelegate
{
  func toolbarWillAddItem(_ notification: Notification)
  {
    guard let item = notification.userInfo?["item"] as? NSToolbarItem,
          item.itemIdentifier == "com.uncommonplace.xit.titlebar",
          let viewController = XTTitleBarAccessoryViewController(
              nibName: "TitleBar", bundle: nil)
    else { return }
    
    let repository = xtDocument!.repository!
    let inverseBindingOptions =
        [NSValueTransformerNameBindingOption:
         NSValueTransformerName.negateBooleanTransformerName]

    titleBarController = viewController
    item.view = viewController.view

    viewController.delegate = self
    viewController.titleLabel.bind("value",
                                   to: window! as NSWindow,
                                   withKeyPath: "title",
                                   options: nil)
    viewController.proxyIcon.bind("hidden",
                                  to: repository,
                                  withKeyPath: "isWriting",
                                  options: nil)
    viewController.spinner.bind("hidden",
                                to: repository,
                                withKeyPath: "isWriting",
                                options: inverseBindingOptions)
    updateBranchList()
    viewController.selectedBranch = xtDocument!.repository!.currentBranch
  }
}
