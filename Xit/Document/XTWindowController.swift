import Cocoa

protocol RepositoryController: class
{
  var repository: Repository { get }
  var queue: TaskQueue { get }
  var selection: RepositorySelection? { get set }
  var isAmending: Bool { get set }

  func select(sha: String)
  func updateForFocus()
  func postIndexNotification()
  func showErrorMessage(error: XTRepository.Error)
}

/// XTDocument's main window controller.
class XTWindowController: NSWindowController, NSWindowDelegate,
                          RepositoryController
{
  @IBOutlet var sidebarController: XTSidebarController!
  @IBOutlet weak var mainSplitView: NSSplitView!
  
  var historyController: XTHistoryViewController!
  weak var xtDocument: XTDocument?
  var titleBarController: TitleBarViewController?
  var refsChangedObserver: NSObjectProtocol?
  var repository: Repository { return (xtDocument?.repository as Repository?)! }
  @objc dynamic var isAmending = false
  {
    didSet
    {
      // Parens work around "assigning a property to itself" error
      (selection = selection) // trigger didSet
    }
  }
  var queue: TaskQueue { return xtDocument!.repository.queue }
  var selection: RepositorySelection?
  {
    didSet
    {
      guard let repo = xtDocument?.repository
      else { return }
      
      if (selection is StagingSelection) &&
         (isAmending != (selection is AmendingSelection)) {
        selection = isAmending ? AmendingSelection(repository: repo)
                               : StagingSelection(repository: repo)
      }
      if let newSelection = selection,
         let oldSelection = oldValue {
        guard newSelection != oldSelection
        else { return }
      }

      var userInfo = [AnyHashable: Any]()
      
      userInfo[NSKeyValueChangeKey.newKey] = selection
      userInfo[NSKeyValueChangeKey.oldKey] = oldValue
      
      NotificationCenter.default.post(
          name: .XTSelectedModelChanged,
          object: self,
          userInfo: userInfo)
      
      if #available(OSX 10.12.2, *) {
        touchBar = makeTouchBar()
      }
      
      if !navigating {
        navForwardStack.removeAll()
        oldValue.map { navBackStack.append($0) }
      }
      updateNavButtons()
    }
  }
  var navBackStack = [RepositorySelection]()
  var navForwardStack = [RepositorySelection]()
  var navigating = false
  var sidebarHidden: Bool
  {
    return mainSplitView.isSubviewCollapsed(mainSplitView.subviews[0])
  }
  var savedSidebarWidth: CGFloat = 180
  
  var currentOperation: XTOperationController?
  
  private var windowObserver, repoObserver: NSKeyValueObservation?
  
  override var document: AnyObject?
  {
    didSet
    {
      xtDocument = document as! XTDocument?
    }
  }
  
  override func windowDidLoad()
  {
    super.windowDidLoad()
    
    let window = self.window!
    
    kdebug_signpost(Signposts.windowControllerLoad, 0, 0, 0, 0)
    window.titleVisibility = .hidden
    window.delegate = self
    historyController = XTHistoryViewController()
    mainSplitView.addArrangedSubview(historyController.view)
    mainSplitView.removeArrangedSubview(mainSplitView.arrangedSubviews[1])
    window.makeFirstResponder(historyController.historyTable)
    
    let repo = xtDocument!.repository!
    
    refsChangedObserver = NotificationCenter.default.addObserver(
        forName: .XTRepositoryRefsChanged,
        object: repo, queue: .main) {
      [weak self] _ in
      self?.updateBranchList()
    }
    windowObserver = window.observe(\.title) {
      [weak self] (_, _) in
      self?.updateMiniwindowTitle()
    }
    repoObserver = repo.observe(\.currentBranch) {
      [weak self] (_, _) in
      self?.titleBarController?.selectedBranch = repo.currentBranch
      self?.updateMiniwindowTitle()
    }
    sidebarController.repo = repo
    historyController.finishLoad(repository: repo)
    updateMiniwindowTitle()
    updateNavButtons()
  }
  
  deinit
  {
    let center = NotificationCenter.default
    
    refsChangedObserver.map { center.removeObserver($0) }
    center.removeObserver(self)
    currentOperation?.canceled = true
  }
  
  func select(sha: String)
  {
    guard let commit = repository.commit(forSHA: sha)
    else { return }
  
    selection = CommitSelection(repository: repository, commit: commit)
  }
  
  func select(oid: GitOID)
  {
    guard let repo = xtDocument?.repository,
          let commit = repo.commit(forOID: oid)
    else { return }
  
    selection = CommitSelection(repository: repo, commit: commit)
  }
  
  /// Update for when a new object has been focused or selected
  func updateForFocus()
  {
    if #available(OSX 10.12.2, *) {
      touchBar = makeTouchBar()
      validateTouchBar()
    }
  }
  
  func postIndexNotification()
  {
    guard let repo = xtDocument?.repository
    else { return }
    let deadline: DispatchTime = .now() + .milliseconds(125)
    
    repo.invalidateIndex()
    DispatchQueue.main.asyncAfter(deadline: deadline) {
      NotificationCenter.default.post(name: .XTRepositoryIndexChanged,
                                      object: repo)
    }
  }
  
  func updateNavButtons()
  {
    updateNavControl(titleBarController?.navButtons)

    if #available(OSX 10.12.2, *),
       let item = touchBar?.item(forIdentifier:
                                 NSTouchBarItem.Identifier.navigation) {
      updateNavControl(item.view as? NSSegmentedControl)
    }
  }
  
  func updateNavControl(_ control: NSSegmentedControl?)
  {
    guard let control = control
    else { return }
    
    control.setEnabled(!navBackStack.isEmpty, forSegment: 0)
    control.setEnabled(!navForwardStack.isEmpty, forSegment: 1)
  }
  
  func updateMiniwindowTitle()
  {
    guard let window = self.window,
          let repo = xtDocument?.repository
    else { return }
    
    var newTitle: String!
  
    if let currentBranch = repo.currentBranch {
      newTitle = "\(window.title) - \(currentBranch)"
    }
    else {
      newTitle = window.title
    }
    window.miniwindowTitle = newTitle
    if #available(OSX 10.13, *) {
      window.tab.title = newTitle
    }
  }
  
  func updateBranchList()
  {
    guard let repo = xtDocument?.repository
    else { return }
    
    titleBarController?.updateBranchList(
        repo.localBranches().compactMap { $0.shortName },
        current: repo.currentBranch)
  }
  
  public func startRenameBranch(_ branchName: String)
  {
    _ = startOperation { XTRenameBranchController(windowController: self,
                                                    branchName: branchName) }
  }
  
  /// Returns the new operation, if any, mostly because the generic type must
  /// be part of the signature.
  @discardableResult
  func startOperation<OperationType: XTSimpleOperationController>()
      -> OperationType?
  {
    return startOperation { return OperationType(windowController: self) }
           as? OperationType
  }
  
  @discardableResult
  func startOperation(factory: () -> XTOperationController)
      -> XTOperationController?
  {
    if let operation = currentOperation {
      NSLog("Can't start new operation, already have \(operation)")
      return nil
    }
    else {
      let operation = factory()
      
      do {
        try operation.start()
        currentOperation = operation
        return operation
      }
      catch let error as XTRepository.Error {
        showErrorMessage(error: error)
        return nil
      }
      catch {
        showErrorMessage(error: XTRepository.Error.unexpected)
        return nil
      }
    }
  }
  
  func showErrorMessage(error: XTRepository.Error)
  {
    guard let window = self.window
    else { return }
    let alert = NSAlert()
    
    alert.messageText = error.message
    alert.beginSheetModal(for: window, completionHandler: nil)
  }
  
  /// Called by the operation controller when it's done.
  func operationEnded(_ operation: XTOperationController)
  {
    if currentOperation == operation {
      currentOperation = nil
    }
  }
  
  func updateRemotesMenu(_ menu: NSMenu)
  {
    let remoteNames = repository.remoteNames()
    
    menu.removeAllItems()
    for name in remoteNames {
      menu.addItem(NSMenuItem(title: name,
                              action: #selector(self.remoteSettings(_:)),
                              keyEquivalent: ""))
    }
  }
  
  func redrawAllHistoryLists()
  {
    for document in NSDocumentController.shared.documents {
      guard let windowController = document.windowControllers.first
                                   as? XTWindowController
      else { continue }
      
      windowController.historyController.tableController.refreshText()
    }
  }
  
  override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
  {
    guard let action = menuItem.action
    else { return false }
    var result = false
    
    switch action {

      case #selector(self.goBack(_:)):
        result = !navBackStack.isEmpty
      
      case #selector(self.goForward(_:)):
        result = !navForwardStack.isEmpty

      case #selector(self.refresh(_:)):
        result = !xtDocument!.repository.isWriting

      case #selector(self.showHideSidebar(_:)):
        result = true
        if sidebarHidden {
          menuItem.title = NSLocalizedString("Show Sidebar", comment: "")
        }
        else {
          menuItem.title = NSLocalizedString("Hide Sidebar", comment: "")
        }

      case #selector(self.verticalLayout(_:)):
        result = true
        menuItem.state = historyController.mainSplitView.isVertical ? .on : .off

      case #selector(self.horizontalLayout(_:)):
        result = true
        menuItem.state = historyController.mainSplitView.isVertical ? .off : .on

      case #selector(self.deemphasizeMerges(_:)):
        result = true
        menuItem.state = Preferences.deemphasizeMerges ? .on : .off

      case #selector(self.remoteSettings(_:)):
        result = true
      
      case #selector(self.newTag(_:)):
        result = true

      default:
        result = false
    }
    return result
  }
  
  func windowWillClose(_ notification: Notification)
  {
    titleBarController?.titleLabel.unbind(◊"value")
    titleBarController?.proxyIcon.unbind(◊"hidden")
    titleBarController?.spinner.unbind(◊"hidden")
    // For some reason this avoids a crash
    window?.makeFirstResponder(nil)
  }
}

// MARK: NSSplitViewDelegate
extension XTWindowController: NSSplitViewDelegate
{
  func splitView(_ splitView: NSSplitView,
                 shouldAdjustSizeOfSubview view: NSView) -> Bool
  {
    if (splitView == mainSplitView) &&
       (view == mainSplitView.arrangedSubviews[0]) {
      return false
    }
    return true
  }
}

// MARK: XTTitleBarDelegate
extension XTWindowController: TitleBarDelegate
{
  func branchSelecetd(_ branch: String)
  {
    try? xtDocument!.repository!.checkOut(branch: branch)
  }
  
  var viewStates: (sidebar: Bool, history: Bool, details: Bool)
  {
    return (!sidebarHidden,
            !historyController.historyHidden,
            !historyController.detailsHidden)
  }
  
  func goBack() { goBack(self) }
  func goForward() { goForward(self) }
  func fetchSelected() { fetch(self) }
  func pushSelected() { push(self) }
  func pullSelected() { pull(self) }
  func showHideSidebar() { showHideSidebar(self) }
  func showHideHistory() { showHideHistory(self) }
  func showHideDetails() { showHideDetails(self) }
}

extension NSBindingName
{
  static let progressHidden =
      NSBindingName(#keyPath(TitleBarViewController.progressHidden))
}

// MARK: NSToolbarDelegate
extension XTWindowController: NSToolbarDelegate
{
  enum NibName
  {
    static let titleBar = NSNib.Name("TitleBar")
  }
  
  func toolbarWillAddItem(_ notification: Notification)
  {
    guard let item = notification.userInfo?["item"] as? NSToolbarItem,
          item.itemIdentifier.rawValue == "com.uncommonplace.xit.titlebar"
    else { return }
    
    let viewController = TitleBarViewController(nibName: NibName.titleBar,
                                                bundle: nil)
    let repository = xtDocument!.repository!
    let inverseBindingOptions =
        [NSBindingOption.valueTransformerName:
         NSValueTransformerName.negateBooleanTransformerName]

    titleBarController = viewController
    item.view = viewController.view

    viewController.delegate = self
    viewController.titleLabel.bind(NSBindingName.value,
                                   to: window! as NSWindow,
                                   withKeyPath: #keyPath(NSWindow.title),
                                   options: nil)
    viewController.proxyIcon.bind(NSBindingName.hidden,
                                  to: repository.queue,
                                  withKeyPath: #keyPath(TaskQueue.busy),
                                  options: nil)
    viewController.bind(.progressHidden,
                        to: repository.queue,
                        withKeyPath: #keyPath(TaskQueue.busy),
                        options: inverseBindingOptions)
    viewController.spinner.startAnimation(nil)
    updateBranchList()
    viewController.selectedBranch = repository.currentBranch
    viewController.observe(repository: repository)
  }
}
