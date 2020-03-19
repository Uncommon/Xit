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
    didSet { selectionChanged(oldValue: selection) }
  }
  var selection: RepositorySelection?
  {
    didSet { selectionChanged(oldValue: oldValue) }
  }

  var navBackStack = [RepositorySelection]()
  var navForwardStack = [RepositorySelection]()
  var navigating = false
  var sidebarHidden: Bool { splitViewController.splitViewItems[0].isCollapsed }
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
        guard let self = self
        else { return }

        // Even though the observer is supposed to be on the main queue,
        // it doesn't always happen.
        DispatchQueue.main.async {
          self.updateTabStatus()
        }
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

  func selectionChanged(oldValue: RepositorySelection?)
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

  public func startRenameBranch(_ branchName: String)
  {
    _ = startOperation { RenameBranchOpController(windowController: self,
                                                  branchName: branchName) }
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

extension NSBindingName
{
  static let progressHidden =
      NSBindingName(#keyPath(TitleBarViewController.progressHidden))
}
