import Cocoa
import Combine
import SwiftUI

@MainActor
protocol RepositoryUIController: AnyObject
{
  var repository: any FullRepository { get }
  var repoController: GitRepositoryController! { get }
  var selection: (any RepositorySelection)? { get set }
  var selectionPublisher: AnyPublisher<RepositorySelection?, Never> { get }
  var reselectPublisher: AnyPublisher<Void, Never> { get }
  var isAmending: Bool { get set }

  func select(oid: GitOID)
  func reselect()
  func updateForFocus()
  func showErrorMessage(error: RepoError)
}

extension RepositoryUIController
{
  var selectionBinding: Binding<(any RepositorySelection)?>
  {
    .init {
      [weak self] in
      self?.selection
    }
    set: {
      [weak self] in
      self?.selection = $0
    }
  }
}

extension RepositoryUIController
{
  var queue: TaskQueue { repoController.queue }
}

/// RepoDocument's main window controller.
final class XTWindowController: NSWindowController,
                                RepositoryUIController
{
  var splitViewController: NSSplitViewController!
  @IBOutlet var sidebarController: SidebarController!
  @IBOutlet var titleBarController: TitleBarController!
  
  var historyController: HistoryViewController!
  var historySplitController: HistorySplitController!
  weak var repoDocument: RepoDocument?
  var repoController: GitRepositoryController!
  var sinks: [AnyCancellable] = []
  var repository: any FullRepository
  { (repoDocument?.repository as (any FullRepository)?)! }

  var defaults: UserDefaults = .xit

  @objc dynamic var isAmending = false
  {
    didSet { selectionChanged(oldValue: selection) }
  }
  var selection: (any RepositorySelection)?
  {
    didSet { selectionChanged(oldValue: oldValue) }
  }
  private let selectionSubject =
      CurrentValueSubject<RepositorySelection?, Never>(nil)
  public var selectionPublisher: AnyPublisher<RepositorySelection?, Never>
  { selectionSubject.eraseToAnyPublisher() }
  private let reselectSubject = PassthroughSubject<Void, Never>()
  public var reselectPublisher: AnyPublisher<Void, Never>
  { reselectSubject.eraseToAnyPublisher() }

  var navBackStack = [any RepositorySelection]()
  var navForwardStack = [any RepositorySelection]()
  var navigating = false
  var sidebarHidden: Bool { splitViewController.splitViewItems[0].isCollapsed }
  var historyAutoCollapsed = false
  
  var currentOperation: OperationController?
  
  private var kvObservers: [NSKeyValueObservation] = []
  private var splitObserver: NSObjectProtocol?

  override func close()
  {
    currentOperation?.canceled = true
    splitObserver.map {
      NotificationCenter.default.removeObserver($0)
    }
    super.close()
  }

  func finalizeSetup()
  {
    guard document != nil,
          let window = self.window
    else {
      preconditionFailure("XTWindowController not configured")
    }
    
    repoDocument = document as! RepoDocument?
    
    guard let repo = repoDocument?.repository
    else { return }
    
    repoController = GitRepositoryController(repository: repo)
    sinks.append(contentsOf: [
//      repoController.refsPublisher.sinkOnMainQueue {
//        [weak self] in
//        self?.updateBranchList()
//      },
      repoController.workspacePublisher.sinkOnMainQueue {
        [weak self] _ in
        self?.updateTabStatus()
      },
      repo.currentBranchPublisher.sink {
        [weak self] in
        self?.titleBarController?.selectedBranch = $0
        self?.updateMiniwindowTitle()
      },
      window.publisher(for: \.tabbedWindows).sink {
        [weak self] _ in
        if let self = self,
           let window = self.window {
          self.updateWindowStyle(window)
        }
      },
    ])
    //sidebarController.repo = repo
    historyController.finishLoad(repository: repo)
    configureTitleBarController(repository: repo)
    updateTabStatus()
    updateWindowStyle(window)

    let tabbedSidebarController =
        TabbedSidebarController(repo: repo,
                                controller: self)
    let tabbedSidebarItem =
          NSSplitViewItem(sidebarWithViewController: tabbedSidebarController)

    splitViewController.splitViewItems.remove(at: 0)
    splitViewController.splitViewItems.insert(tabbedSidebarItem, at: 0)
  }
  
  func updateWindowStyle(_ window: NSWindow)
  {
    guard let toolbar = window.toolbar
    else {
      assertionFailure("no toolbar")
      return
    }
    var style = window.styleMask
    let findSeparator: (NSToolbarItem) -> Bool = {
      $0.itemIdentifier == .sidebarTrackingSeparator
    }
    
    if window.tabbedWindows == nil {
      style.formUnion([.fullSizeContentView])
      if !toolbar.items.contains(where: findSeparator) {
        toolbar.insertItem(withItemIdentifier: .sidebarTrackingSeparator, at: 3)
      }
    }
    else {
      style.remove(.fullSizeContentView)
      if let separatorIndex = toolbar.items.firstIndex(where: findSeparator) {
        toolbar.removeItem(at: separatorIndex)
      }
    }
    window.styleMask = style
  }

  @objc
  func shutDown()
  {
    repoController.queue.shutDown()
    currentOperation?.abort()
    WaitForQueue(repoController.queue.queue)
  }

  func updateHistoryCollapse(wasStaging: Bool)
  {
    guard let repo = repoDocument?.repository
    else {
      assertionFailure("no repository")
      return
    }

    if let stagingSelection = selection as? StagedUnstagedSelection {
      if isAmending != stagingSelection.amending {
        selection = StagingSelection(repository: repo, amending: isAmending)
      }
      if defaults.collapseHistory {
        historyAutoCollapsed = true
        if !historyController.historyHidden {
          historySplitController.toggleHistory(self)
          titleBarController?.updateViewControls()
        }
      }
    }
    else if wasStaging &&
            defaults.collapseHistory &&
            historyAutoCollapsed {
      if historyController.historyHidden {
        historySplitController.toggleHistory(self)
        titleBarController?.updateViewControls()
      }
      historyAutoCollapsed = false
    }
  }

  func selectionChanged(oldValue: (any RepositorySelection)?)
  {
    updateHistoryCollapse(wasStaging: oldValue is StagingSelection)
    if let newSelection = selection,
       let oldSelection = oldValue,
       newSelection == oldSelection {
      return
    }

    selectionSubject.send(selection)

    touchBar = makeTouchBar()

    if !navigating {
      navForwardStack.removeAll()
      oldValue.map { navBackStack.append($0) }
    }
    updateNavButtons()
  }
  
  func select(oid: GitOID)
  {
    guard let repo = repoDocument?.repository,
          let commit = repo.commit(forOID: oid)
    else { return }
  
    selection = CommitSelection(repository: repo, commit: commit)
  }

  func reselect()
  {
    reselectSubject.send()
  }
  
  /// Update for when a new object has been focused or selected
  func updateForFocus()
  {
    touchBar = makeTouchBar()
    validateTouchBar()
  }

  nonisolated func updateMiniwindowTitle()
  {
    DispatchQueue.main.async {
      [weak self] in
      guard let self = self,
            let window = self.window,
            let repo = self.repoDocument?.repository
      else { return }
      
      var newTitle: String!
    
      if let currentBranch = repo.currentBranch {
        newTitle = "\(window.title) - \(currentBranch)"
      }
      else {
        newTitle = window.title
      }
      window.miniwindowTitle = newTitle
      window.tab.title = newTitle
    }
  }
  
  private func updateTabStatus()
  {
//    guard let tab = window?.tab
//    else { return }
//    
//    guard defaults.statusInTabs,
//          let stagingItem = sidebarController.model.rootItem(.workspace)
//                                             .children.first,
//          let selection = stagingItem.selection as? StagedUnstagedSelection
//    else {
//      tab.accessoryView = nil
//      return
//    }
//    
//    let tabButton = tab.accessoryView as? WorkspaceStatusIndicator ??
//                    WorkspaceStatusIndicator()
//    let (stagedCount, unstagedCount) = selection.counts()
//
//    tabButton.setStatus(unstaged: unstagedCount, staged: stagedCount)
//    tabButton.setAccessibilityIdentifier("tabStatus")
//    tab.accessoryView = tabButton
  }

  public func startRenameBranch(_ branchName: String)
  {
    _ = startOperation { RenameBranchOpController(windowController: self,
                                                  branchName: branchName) }
  }
  
  func updateRemotesMenu(_ menu: NSMenu)
  {
    let remoteNames = repository.remoteNames()

    menu.items = remoteNames.map { NSMenuItem($0, remoteSettings(_:)) }
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
  
}

extension XTWindowController: NSWindowDelegate
{
  override func windowDidLoad()
  {
    super.windowDidLoad()
    
    let window = self.window!
    
    Signpost.event(.windowControllerLoad)
    window.delegate = self
    splitViewController = contentViewController as? NSSplitViewController
    titleBarController.splitView = splitViewController.splitView
    //sidebarController = splitViewController.splitViewItems[0].viewController
    //    as? SidebarController

    historySplitController = splitViewController.splitViewItems[1].viewController
                             as? HistorySplitController
    historyController = historySplitController.historyController
    _ = historyController.view // force load

    window.makeFirstResponder(historyController.historyTable)

    kvObservers.append(window.observe(\.title) {
      [weak self] (_, _) in
      self?.updateMiniwindowTitle()
    })
    kvObservers.append(defaults.observe(\.deemphasizeMerges) {
      [weak self] (_, _) in
      MainActor.assumeIsolated { self?.redrawAllHistoryLists() }
    })
    kvObservers.append(defaults.observe(\.statusInTabs) {
      [weak self] (_, _) in
      MainActor.assumeIsolated { self?.updateTabStatus() }
    })
    splitObserver = NotificationCenter.default.addObserver(
        forName: NSSplitView.didResizeSubviewsNotification,
        object: historySplitController.splitView, queue: .main) {
      [weak self] (_) in
      guard let self = self
      else { return }
      MainActor.assumeIsolated {
        let split = self.historySplitController.splitView
        let frameSize = split.subviews[0].frame.size
        let paneSize = split.isVertical ? frameSize.width : frameSize.height
        let collapsed = paneSize == 0

        if !collapsed {
          self.historyAutoCollapsed = false
        }
        self.titleBarController?.searchButton?.isEnabled = !collapsed
        self.titleBarController?.updateViewControls()
      }
    }
    
    updateMiniwindowTitle()
    updateNavButtons()
  }

  func windowWillClose(_ notification: Notification)
  {
    titleBarController.spinner?.unbind(◊"hidden")
    // For some reason this avoids a crash
    window?.makeFirstResponder(nil)
  }
}

extension XTWindowController: NSMenuDelegate
{
  enum RemoteMenuType: CaseIterable
  {
    case fetch, push, pull

    var identifier: NSUserInterfaceItemIdentifier
    {
      switch self {
        case .fetch: return ◊"fetchRemote"
        case .push:  return ◊"pushRemote"
        case .pull:  return ◊"pullRemote"
      }
    }
    var selector: Selector
    {
      switch self {
        case .fetch: return #selector(XTWindowController.fetchRemote(_:))
        case .push:  return #selector(XTWindowController.pushToRemote(_:))
        case .pull:  return #selector(XTWindowController.pullRemote(_:))
      }
    }

    func command(for remote: String) -> UIString
    {
      switch self {
        case .fetch: return .fetchRemote(remote)
        case .push:  return .pushRemote(remote)
        case .pull:  return .pullRemote(remote)
      }
    }

    static func of(_ menu: NSMenu) -> RemoteMenuType?
    {
      return menu.items.firstResult {
        (item) in
        guard let id = item.identifier
        else { return nil }
        return allCases.first { $0.identifier == id }
      }
    }
  }
  
  func menuWillOpen(_ menu: NSMenu)
  {
    guard let type = RemoteMenuType.of(menu)
    else { return }

    for item in menu.items where item.action == type.selector {
      menu.removeItem(item)
    }

    for (index, remote) in self.repository.remoteNames().enumerated() {
      let item = NSMenuItem(titleString: type.command(for: remote),
                            action: type.selector,
                            keyEquivalent: "")

      item.tag = index
      menu.addItem(item)
    }
  }
}
