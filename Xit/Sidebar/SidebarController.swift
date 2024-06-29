import Cocoa
import Combine

/// Manages the main window sidebar.
final class SidebarController: NSViewController, SidebarCommandHandler,
                               RepositoryWindowViewController
{
  @IBOutlet weak var sidebarOutline: SideBarOutlineView!
  @IBOutlet weak var sidebarDS: SideBarDataSource!
  @IBOutlet weak var sidebarDelegate: SidebarDelegate!
  
  var branchContextMenu: NSMenu!
  var remoteBranchContextMenu: NSMenu!
  var remoteContextMenu: NSMenu!
  var tagContextMenu: NSMenu!
  var stashContextMenu: NSMenu!
  var submoduleContextMenu: NSMenu!
  
  private(set) var model: SidebarDataModel!
  private(set) var pullRequestManager: SidebarPRManager! = nil
  private(set) var buildStatusController: BuildStatusController! = nil

  private var sinks: [AnyCancellable] = []

  weak var repo: XTRepository!
  {
    didSet
    {
      model = SidebarDataModel(repository: repo)
      pullRequestManager = SidebarPRManager(model: model, outline: sidebarOutline)
      buildStatusController = BuildStatusController(model: model,
                                                    display: sidebarDelegate)
      if Services.xit.allServices
                 .contains(where: { $0 is PullRequestService }) {
        pullRequestManager.scheduleCacheRefresh()
      }
      
      sidebarDS.model = model
      sidebarDelegate.model = model
      sidebarDelegate.pullRequestManager = pullRequestManager
      sidebarDelegate.buildStatusController = buildStatusController

      if let controller = repoUIController?.repoController {
        sinks.append(controller.indexPublisher
          .sinkOnMainQueue {
            [weak self] in
            self?.sidebarOutline.reloadItem(self?.sidebarDS.stagingItem)
          })
        sinks.append(controller.refsPublisher
          .sinkOnMainQueue {
            [weak self] in
            self?.reload()
          })
        sinks.append(controller.workspacePublisher
                      .sinkOnMainQueue {
          [weak self] _ in
          self?.sidebarOutline.reloadItem(self?.sidebarDS.stagingItem)
        })
      }
      else {
        assertionFailure("repoUIController is missing")
      }
    }
  }
  var window: NSWindow? { view.window }
  var savedSidebarWidth: UInt = 0
  var statusPopover: NSPopover?

  private var cancellables: [AnyCancellable] = []

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

  func makeMenus()
  {
    branchContextMenu = NSMenu {
      NSMenuItem(.checkOut, target: self, action: #selector(checkOutBranch(_:)))
        .axid(.BranchPopup.checkOut)
      NSMenuItem(.rename, target: self, action: #selector(renameBranch(_:)))
        .axid(.BranchPopup.rename)
      NSMenuItem(.merge, target: self, action: #selector(mergeBranch(_:)))
        .axid(.BranchPopup.merge)
      NSMenuItem.separator()
      NSMenuItem(.delete, target: self, action: #selector(deleteBranch(_:)))
        .axid(.BranchPopup.delete)
    }.axid(.Menu.branch)
    remoteBranchContextMenu = NSMenu {
      NSMenuItem(.createTrackingBranch, target: self,
                 action: #selector(createTrackingBranch(_:)))
        .axid(.RemoteBranchPopup.createTracking)
      NSMenuItem(.rename, target: self, action: #selector(renameBranch(_:)))
        .axid(.BranchPopup.merge)
      NSMenuItem(.merge, target: self, action: #selector(mergeBranch(_:)))
      NSMenuItem.separator()
      NSMenuItem(.delete, target: self, action: #selector(deleteBranch(_:)))
        .axid(.BranchPopup.delete)
    }.axid(.Menu.remoteBranch)
    remoteContextMenu = NSMenu {
      NSMenuItem(.rename, target: self, action: #selector(renameRemote(_:)))
      NSMenuItem(.edit, target: self, action: #selector(editRemote(_:)))
      NSMenuItem(.delete, target: self, action: #selector(deleteRemote(_:)))
      NSMenuItem(.copyURL, target: self, action: #selector(copyRemoteURL(_:)))
    }
    stashContextMenu = NSMenu {
      NSMenuItem(.pop, target: self, action: #selector(popStash(_:)))
        .axid(.StashPopup.pop)
      NSMenuItem(.apply, target: self, action: #selector(applyStash(_:)))
        .axid(.StashPopup.apply)
      NSMenuItem(.drop, target: self, action: #selector(dropStash(_:)))
        .axid(.StashPopup.drop)
    }
    submoduleContextMenu = NSMenu {
      NSMenuItem(.showInFinder, target: self, action: #selector(showSubmodule(_:)))
      NSMenuItem(.update, target: self, action: #selector(updateSubmodule(_:)))
    }
    tagContextMenu = NSMenu {
      NSMenuItem(.delete, target: self, action: #selector(deleteTag(_:)))
        .axid(.TagPopup.delete)
    }.axid(.Menu.tag)
  }
  
  override func viewDidLoad()
  {
    sidebarOutline.floatsGroupRows = false
    makeMenus()
  }
  
  override func viewWillAppear()
  {
    let repoUIController = view.window!.windowController as! XTWindowController
    
    if cancellables.isEmpty {
      cancellables.append(contentsOf: [
        repoUIController.publisher(for: \.isAmending).sink {
          [weak self] (amending) in
          self?.sidebarDS.setAmending(amending)
        },
        repoUIController.selectionPublisher.sink {
          [weak self] (_) in
          self?.selectedModelChanged()
        }
      ])
    }
  }

  override func viewWillDisappear()
  {
    pullRequestManager?.stopCacheRefresh()
  }
  
  func selectedModelChanged()
  {
    if let selectedItem = self.selectedItem {
      guard selectedItem.selection?.target !=
            repoUIController?.selection?.target
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
        let selectedGitOID = commitChanges.target.oid
        guard let ref = selectedGitOID.map({ repo.refs(at: $0) })?
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
    Task {
      if await confirmDelete(kind: "branch", name: item.title) {
        self.callCommand(targetItem: item) {
          [weak self] (item) in
          _ = try? self?.repo.deleteBranch(item.title)
        }
      }
    }
  }

  func confirmDelete(kind: String, name: String) async -> Bool
  {
    guard let window = view.window
    else { return false }
    let alert = NSAlert()

    alert.messageString = .confirmDelete(kind: kind, name: name)
    alert.addButton(withString: .delete)
    alert.addButton(withString: .cancel)
    alert.buttons[0].hasDestructiveAction = true
    // Delete is destructive, so it should not be default
    alert.buttons[0].keyEquivalent = ""

    let button = await alert.beginSheetModal(for: window)

    return button == .alertFirstButtonReturn
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
