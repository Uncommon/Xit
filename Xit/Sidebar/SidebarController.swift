import Cocoa
import Combine

/// Manages the main window sidebar.
class SidebarController: NSViewController, SidebarCommandHandler,
                         RepositoryWindowViewController
{
  @IBOutlet weak var sidebarOutline: SideBarOutlineView!
  @IBOutlet weak var sidebarDS: SideBarDataSource!
  @IBOutlet weak var sidebarDelegate: SidebarDelegate!
  
  @IBOutlet var branchContextMenu: NSMenu!
  @IBOutlet var remoteBranchContextMenu: NSMenu!
  @IBOutlet var remoteContextMenu: NSMenu!
  @IBOutlet var tagContextMenu: NSMenu!
  @IBOutlet var stashContextMenu: NSMenu!
  @IBOutlet var submoduleContextMenu: NSMenu!
  
  private(set) var model: SidebarDataModel!
  private(set) var pullRequestManager: SidebarPRManager! = nil
  private(set) var buildStatusController: BuildStatusController! = nil

  private var indexSink: AnyCancellable?

  weak var repo: XTRepository!
  {
    didSet
    {
      model = SidebarDataModel(repository: repo, outlineView: sidebarOutline)
      pullRequestManager = SidebarPRManager(model: model)
      buildStatusController = BuildStatusController(model: model,
                                                    display: sidebarDelegate)
      if Services.shared.allServices
                 .contains(where: { $0 is PullRequestService }) {
        pullRequestManager.scheduleCacheRefresh()
      }
      
      sidebarDS.model = model
      sidebarDelegate.model = model
      sidebarDelegate.pullRequestManager = pullRequestManager
      sidebarDelegate.buildStatusController = buildStatusController

      let center = NotificationCenter.default

      indexSink = repoUIController?.repoController.indexPublisher
        .receive(on: DispatchQueue.main)
        .sink {
          [weak self] in
          self?.sidebarOutline.reloadItem(self?.sidebarDS.stagingItem)
        }
      center.addObserver(forName: .XTRepositoryWorkspaceChanged,
                            object: repo, queue: .main) {
        [weak self] (_) in
        self?.sidebarOutline.reloadItem(self?.sidebarDS.stagingItem)
      }
      center.addObserver(forName: .XTRepositoryRefsChanged,
                         object: repo, queue: .main) {
        [weak self] (_) in
        self?.reload()
      }
    }
  }
  var window: NSWindow? { view.window }
  var savedSidebarWidth: UInt = 0
  var amendingObserver: NSKeyValueObservation?
  var statusPopover: NSPopover?

  var selectedItem: SidebarItem?
  {
    get
    {
      let row = sidebarOutline.selectedRow
      
      return row >= 0 ? sidebarOutline.item(atRow: row) as? SidebarItem : nil
    }
    set
    {
      guard let controller = repoUIController,
            let item = newValue
      else { return }
      
      let row = sidebarOutline.row(forItem: item)
      
      if row >= 0 {
        sidebarOutline.selectRowIndexes(IndexSet(integer: row),
                                        byExtendingSelection: false)
        
        item.selection.map { controller.selection = $0 }
      }
    }
  }

  deinit
  {
    // The timers contain references to the ds object and repository.
    sidebarDS?.stopTimers()
    pullRequestManager?.stopCacheRefresh()
  }
  
  override func viewDidLoad()
  {
    sidebarOutline.floatsGroupRows = false
  
    if branchContextMenu == nil,
       let menuNib = NSNib(nibNamed: "Sidebar Menus", bundle: nil) {
      menuNib.instantiate(withOwner: self, topLevelObjects: nil)
    }
  }
  
  override func viewWillAppear()
  {
    let repoUIController = view.window!.windowController as! XTWindowController
    
    if amendingObserver == nil {
      amendingObserver = repoUIController.observe(\.isAmending) {
        [weak self] (controller, _) in
        self?.sidebarDS.setAmending(controller.isAmending)
      }
      NotificationCenter.default.addObserver(
          forName: .XTSelectedModelChanged,
          object: repoUIController, queue: .main) {
        [weak self] (_) in
        self?.selectedModelChanged()
      }
    }
  }
  
  func selectedModelChanged()
  {
    if let selectedItem = self.selectedItem {
      guard selectedItem.selection?.shaToSelect !=
            repoUIController?.selection?.shaToSelect
      else {
        return
      }
    }
    
    switch repoUIController?.selection {
    
      case let stashChanges as StashSelection:
        let stashRoot = sidebarDS.model.rootItem(.stashes)
        guard let stashItem = stashRoot.children.first(where: {
          $0.selection.map({ (selection) in selection == stashChanges }) ?? false
        })
        else { break }
        
        self.sidebarOutline.selectRowIndexes(
            IndexSet(integer: sidebarOutline.row(forItem: stashItem)),
            byExtendingSelection: false)
      
      case let commitChanges as CommitSelection:
        guard let ref = commitChanges.shaToSelect.map({ repo.refs(at: $0) })?
                                                 .first
        else { break }
      
        select(ref: ref)
      
      default:
        break
    }
  }
  
  func reload()
  {
    sidebarDS.reload()
    sidebarDelegate.updateVisibleCells()
  }
  
  func reloadFinished()
  {
    DispatchQueue.main.async {
      [weak self] in
      self?.buildStatusController.buildStatusCache.refresh()
      self?.pullRequestManager.pullRequestCache.refresh()
    }
  }
  
  func selectedBranch() -> String?
  {
    let selection = sidebarOutline.item(atRow: sidebarOutline.selectedRow)
                    as? LocalBranchSidebarItem
    
    return selection?.title
  }
  
  func selectItem(_ item: SidebarItem, group: SidebarGroupIndex)
  {
    sidebarOutline.expandItem(
        sidebarOutline.item(atRow: group.rawValue))
    
    let row = sidebarOutline.row(forItem: item)
    
    if row != -1 {
      sidebarOutline.selectRowIndexes(IndexSet(integer: row),
                                      byExtendingSelection: false)
    }
  }
  
  func selectItem(name: String, group: SidebarGroupIndex)
  {
    if let item = sidebarDS.model.item(named: name, inGroup: group) {
      selectItem(item, group: group)
    }
  }
  
  @objc(selectBranch:)
  func select(branch: String)
  {
    selectItem(name: branch, group: .branches)
  }
  
  func select(remoteBranch: String)
  {
    let slices = remoteBranch.split(separator: "/", maxSplits: 1)
                             .map { String($0) }
    guard slices.count == 2
    else { return }
    let remote = slices[0]
    let branch = slices[1]
    let remotesGroup = sidebarDS.model.rootItem(.remotes)
    guard let remoteItem = remotesGroup.children
                                       .first(where: { $0.title == remote }),
          let branchItem = remoteItem.child(matching: branch)
    else { return }
    
    selectItem(branchItem, group: .remotes)
  }
  
  func select(tag: String)
  {
    selectItem(name: tag, group: .tags)
  }
  
  func select(ref: String)
  {
    switch ref {
      
      case let branchRef where branchRef.hasPrefix(RefPrefixes.heads):
        select(branch: branchRef.droppingPrefix(RefPrefixes.heads))
      
      case let remoteRef where remoteRef.hasPrefix(RefPrefixes.remotes):
        select(remoteBranch:
            remoteRef.droppingPrefix(RefPrefixes.remotes))
      
      case let tagRef where tagRef.hasPrefix(GitTag.tagPrefix):
        select(tag: tagRef.droppingPrefix(GitTag.tagPrefix))
      
      default:
        break
    }
  }
  
  func targetRow() -> Int
  {
    if let row = sidebarOutline.contextMenuRow {
      return row
    }
    return sidebarOutline.selectedRow
  }
  
  func targetItem() -> SidebarItem?
  {
    return sidebarOutline.item(atRow: targetRow()) as? SidebarItem
  }
  
  func stashIndex(for item: SidebarItem) -> UInt?
  {
    let stashes = sidebarDS.model.rootItem(.stashes)
    
    return stashes.children.firstIndex(of: item).map { UInt($0) }
  }
  
  func editSelectedRow()
  {
    sidebarOutline.editColumn(0, row: targetRow(), with: nil, select: true)
  }
  
  func deleteBranch(item: SidebarItem)
  {
    confirmDelete(kind: "branch", name: item.title) {
      self.callCommand(targetItem: item) {
        [weak self] (item) in
        _ = self?.repo.deleteBranch(item.title)
      }
    }
  }
  
  func confirmDelete(kind: String, name: String,
                     onConfirm: @escaping () -> Void)
  {
    let alert = NSAlert.init()
    
    alert.messageString = .confirmDelete(kind: kind, name: name)
    alert.addButton(withString: .delete)
    alert.addButton(withString: .cancel)
    alert.buttons[0].hasDestructiveAction = true
    // Delete is destructive, so it should not be default
    alert.buttons[0].keyEquivalent = ""
    alert.beginSheetModal(for: view.window!) {
      (response) in
      if response == .alertFirstButtonReturn {
        onConfirm()
      }
    }
  }
}

extension SidebarController: SidebarBottomDelegate
{
  func updateFilter(string: String?)
  {
    if let string = string {
      sidebarDS.filterSet.filters = [SidebarNameFilter(string: string)]
    }
    else {
      sidebarDS.filterSet.filters.removeAll()
    }
    reload()
  }
  
  func newBranch()
  {
  }
  
  func newRemote()
  {
  }
  
  func newTag()
  {
  }
}

extension SidebarController: NSMenuItemValidation
{
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
  {
    return validate(sidebarCommand: menuItem)
  }
}

extension SidebarController: NSPopoverDelegate
{
  func popoverDidClose(_ notification: Notification)
  {
    statusPopover = nil
  }
}
