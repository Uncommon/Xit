import Cocoa

protocol RepositoryUIController: AnyObject
{
  var repository: Repository { get }
  var repoController: GitRepositoryController! { get }
  var selection: RepositorySelection? { get set }
  var isAmending: Bool { get set }

  func select(sha: String)
  func updateForFocus()
  func postIndexNotification()
  func showErrorMessage(error: RepoError)
}

extension RepositoryUIController
{
  var queue: TaskQueue { repoController.queue }
}

/// XTDocument's main window controller.
class XTWindowController: NSWindowController, NSWindowDelegate,
                          RepositoryUIController
{
  var splitViewController: NSSplitViewController!
  @IBOutlet var sidebarController: SidebarController!
  
  var historyController: HistoryViewController!
  weak var xtDocument: XTDocument?
  var repoController: GitRepositoryController!
  var titleBarController: TitleBarViewController?
  var refsChangedObserver, workspaceObserver: NSObjectProtocol?
  var repository: Repository { return (xtDocument?.repository as Repository?)! }
  @objc dynamic var isAmending = false
  {
    didSet
    {
      // Parens work around "assigning a property to itself" error
      (selection = selection) // trigger didSet
    }
  }
  var selection: RepositorySelection?
  {
    didSet
    {
      guard let repo = xtDocument?.repository
      else { return }
      
      if selection is StagingSelection {
        if isAmending != (selection is AmendingSelection) {
          selection = isAmending ? AmendingSelection(repository: repo)
                                 : StagingSelection(repository: repo)
        }
        if UserDefaults.standard.collapseHistory {
          historyAutoCollapsed = true
          if !historyController.historyHidden {
            historyController.toggleHistory(self)
            titleBarController?.updateViewControls()
          }
        }
      }
      else if oldValue is StagingSelection &&
              UserDefaults.standard.collapseHistory &&
              historyAutoCollapsed {
        if historyController.historyHidden {
          historyController.toggleHistory(self)
          titleBarController?.updateViewControls()
        }
        historyAutoCollapsed = false
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
    return splitViewController.splitViewItems[0].isCollapsed
  }
  var savedSidebarWidth: CGFloat = 180
  var historyAutoCollapsed = false
  
  @objc
  var currentOperation: OperationController?
  
  private var kvObservers: [NSKeyValueObservation] = []
  private var splitObserver: NSObjectProtocol?
  
  override var document: AnyObject?
  {
    didSet
    {
      guard document != nil
      else { return }
      
      xtDocument = document as! XTDocument?
      
      guard let repo = xtDocument?.repository
      else { return }
      
      repoController = GitRepositoryController(repository: repo)
      refsChangedObserver = NotificationCenter.default.addObserver(
          forName: .XTRepositoryRefsChanged,
          object: repo, queue: .main) {
        [weak self] _ in
        self?.updateBranchList()
      }
      workspaceObserver = NotificationCenter.default.addObserver(
          forName: .XTRepositoryWorkspaceChanged, object: repo, queue: .main) {
        [weak self] (_) in
        self?.updateTabStatus()
      }
      kvObservers.append(repo.observe(\.currentBranch) {
        [weak self] (_, _) in
        self?.titleBarController?.selectedBranch = repo.currentBranch
        self?.updateMiniwindowTitle()
      })
      sidebarController.repo = repo
      historyController.finishLoad(repository: repo)
      configureTitleBarController(repository: repo)
      updateTabStatus()
    }
  }
  
  override func windowDidLoad()
  {
    super.windowDidLoad()
    
    let window = self.window!
    
    Signpost.event(.windowControllerLoad)
    window.titleVisibility = .hidden
    window.delegate = self
    splitViewController = contentViewController as? NSSplitViewController
    sidebarController = splitViewController.splitViewItems[0].viewController
        as? SidebarController
    historyController = HistoryViewController()
    splitViewController.removeSplitViewItem(splitViewController.splitViewItems[1])
    splitViewController.addSplitViewItem(
        NSSplitViewItem(viewController: historyController))
    window.makeFirstResponder(historyController.historyTable)
    
    kvObservers.append(window.observe(\.title) {
      [weak self] (_, _) in
      self?.updateMiniwindowTitle()
    })
    kvObservers.append(UserDefaults.standard.observe(\.deemphasizeMerges) {
      [weak self] (_, _) in
      self?.redrawAllHistoryLists()
    })
    kvObservers.append(UserDefaults.standard.observe(\.statusInTabs) {
      [weak self] (_, _) in
      self?.updateTabStatus()
    })
    splitObserver = NotificationCenter.default.addObserver(
        forName: NSSplitView.didResizeSubviewsNotification,
        object: historyController.mainSplitView, queue: nil) {
      [weak self] (_) in
      guard let self = self,
            let split = self.historyController.mainSplitView
      else { return }
      let frameSize = split.subviews[0].frame.size
      let paneSize = split.isVertical ? frameSize.width : frameSize.height
      let collapsed = paneSize == 0

      if !collapsed {
        self.historyAutoCollapsed = false
      }
      self.titleBarController?.searchButton.isEnabled = !collapsed
      self.titleBarController?.updateViewControls()
    }
    updateMiniwindowTitle()
    updateNavButtons()
  }
  
  @objc
  func shutDown()
  {
    repoController.queue.shutDown()
    currentOperation?.abort()
    WaitForQueue(repoController.queue.queue)
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
    DispatchQueue.main.async {
      guard let window = self.window,
            let repo = self.xtDocument?.repository
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
  }
  
  private func updateTabStatus()
  {
    guard let tab = window?.tab
    else { return }
    
    guard UserDefaults.standard.statusInTabs,
          let stagingItem = sidebarController.model.rootItem(.workspace)
                                             .children.first,
          let selection = stagingItem.selection as? StagedUnstagedSelection
    else {
      tab.accessoryView = nil
      return
    }
    
    let tabButton = tab.accessoryView as? WorkspaceStatusIndicator ??
                    WorkspaceStatusIndicator()
    let (stagedCount, unstagedCount) = selection.counts()

    tabButton.setStatus(unstaged: unstagedCount, staged: stagedCount)
    tabButton.setAccessibilityIdentifier("tabStatus")
    tab.accessoryView = tabButton
  }
  
  func updateBranchList()
  {
    guard let repo = xtDocument?.repository
    else { return }
    
    titleBarController?.updateBranchList(
        repo.localBranches.compactMap { $0.shortName },
        current: repo.currentBranch)
  }
  
  public func startRenameBranch(_ branchName: String)
  {
    _ = startOperation { RenameBranchOpController(windowController: self,
                                                  branchName: branchName) }
  }
  
  /// Returns the new operation, if any, mostly because the generic type must
  /// be part of the signature.
  @discardableResult
  func startOperation<OperationType: SimpleOperationController>()
      -> OperationType?
  {
    return startOperation { return OperationType(windowController: self) }
           as? OperationType
  }
  
  @discardableResult
  func startOperation(factory: () -> OperationController)
      -> OperationController?
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
      catch let error as RepoError {
        showErrorMessage(error: error)
        return nil
      }
      catch {
        showErrorMessage(error: RepoError.unexpected)
        return nil
      }
    }
  }
  
  func showErrorMessage(error: RepoError)
  {
    guard let window = self.window
    else { return }
    let alert = NSAlert()
    
    alert.messageString = error.message
    alert.beginSheetModal(for: window, completionHandler: nil)
  }
  
  /// Called by the operation controller when it's done.
  func operationEnded(_ operation: OperationController)
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
  
  func windowWillClose(_ notification: Notification)
  {
    titleBarController?.titleLabel.unbind(◊"value")
    titleBarController?.proxyIcon.unbind(◊"hidden")
    titleBarController?.spinner.unbind(◊"hidden")
    // For some reason this avoids a crash
    window?.makeFirstResponder(nil)
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
  func stashSelected() { stash(self) }
  func popStashSelected() { popStash(self) }
  func applyStashSelected() { applyStash(self) }
  func dropStashSelected() { dropStash(self) }
  func showHideSidebar() { showHideSidebar(self) }
  func showHideHistory() { showHideHistory(self) }
  func showHideDetails() { showHideDetails(self) }
  
  func search()
  {
    historyController.toggleScopeBar()
  }
}

extension NSBindingName
{
  static let progressHidden =
      NSBindingName(#keyPath(TitleBarViewController.progressHidden))
}

// MARK: NSToolbarDelegate
extension XTWindowController: NSToolbarDelegate
{
  func toolbarWillAddItem(_ notification: Notification)
  {
    guard let item = notification.userInfo?["item"] as? NSToolbarItem,
          item.itemIdentifier.rawValue == "com.uncommonplace.xit.titlebar"
    else { return }
    
    let viewController = TitleBarViewController(nibName: .titleBarNib,
                                                bundle: nil)

    titleBarController = viewController
    item.view = viewController.view

    viewController.delegate = self
    viewController.titleLabel.bind(NSBindingName.value,
                                   to: window! as NSWindow,
                                   withKeyPath: #keyPath(NSWindow.title),
                                   options: nil)
    viewController.spinner.startAnimation(nil)
  }
  
  func configureTitleBarController(repository: XTRepository)
  {
    let viewController: TitleBarViewController = titleBarController!
    let inverseBindingOptions =
        [NSBindingOption.valueTransformerName:
         NSValueTransformerName.negateBooleanTransformerName]

    viewController.proxyIcon.bind(NSBindingName.hidden,
                                  to: queue,
                                  withKeyPath: #keyPath(TaskQueue.busy),
                                  options: nil)
    viewController.bind(.progressHidden,
                        to: queue,
                        withKeyPath: #keyPath(TaskQueue.busy),
                        options: inverseBindingOptions)
    viewController.selectedBranch = repository.currentBranch
    viewController.observe(repository: repository)
    updateBranchList()
  }
}
