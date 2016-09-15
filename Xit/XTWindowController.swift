import Cocoa

/// XTDocument's main window controller.
class XTWindowController: NSWindowController, NSWindowDelegate {
  
  @IBOutlet var historyController: XTHistoryViewController!
  @IBOutlet var activity: NSProgressIndicator!
  @IBOutlet var activityController: XTActivityViewController!
  weak var xtDocument: XTDocument?
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
    window!.delegate = self
    // We could set the window's contentViewController, but then it would
    // retain the view controller, which is undesirable.
    window!.contentView = historyController.view
    window!.makeFirstResponder(historyController.historyTable)
    window!.addTitlebarAccessoryViewController(activityController)
    
    let repo = xtDocument!.repository
    
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
    historyController.windowDidLoad()
    historyController.setRepo(repo)
  }
  
  func windowWillClose(_ notification: Notification)
  {
    guard let toolbarDelegate = window?.toolbar?.delegate as? XTToolbarDelegate
    else { return }
    
    toolbarDelegate.finalizeItems()
  }
  
  deinit
  {
    NotificationCenter.default.removeObserver(self)
    currentOperation?.canceled = true
  }
  
  func taskStarted(_ notification: Notification)
  {
    activityController.activityStarted()
  }
  
  func taskEnded(_ notification: Notification)
  {
    activityController.activityEnded()
  }
  
  @IBAction func refresh(_ sender: AnyObject)
  {
    historyController.reload()
  }
  
  @IBAction func showHideSidebar(_ sender: AnyObject)
  {
    historyController.toggleSideBar(sender)
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
  
  @IBAction func networkSegmentClicked(_ sender: AnyObject)
  {
    switch (sender as! NSSegmentedControl).selectedSegment {
      case 0:
        fetch(sender)
      case 1:
        pull(sender)
      case 2:
        push(sender)
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
