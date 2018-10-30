import Cocoa

// Command handling extracted for testability
protocol SidebarHandler: AnyObject
{
  var repo: XTRepository! { get }
  var window: NSWindow? { get }
  
  func targetItem() -> SidebarItem?
  func stashIndex(for item: SidebarItem) -> UInt?
}

enum XTGroupIndex: Int
{
  case workspace
  case branches
  case remotes
  case tags
  case stashes
  case submodules
}

extension SidebarHandler
{
  func validate(sidebarCommand: NSMenuItem) -> Bool
  {
    guard let action = sidebarCommand.action,
          let item = targetItem()
    else { return false }
    
    switch action {
      
      case #selector(SidebarController.checkOutBranch(_:)):
        guard let branch = (item as? BranchSidebarItem)?.branchObject()
        else { return false }
        sidebarCommand.titleString = .checkOut(branch.strippedName)
        return !repo.isWriting && item.title != repo.currentBranch
      
      case #selector(SidebarController.createTrackingBranch(_:)):
        return !repo.isWriting
      
      case #selector(SidebarController.renameBranch(_:)),
           #selector(SidebarController.mergeBranch(_:)),
           #selector(SidebarController.deleteBranch(_:)):
        if !item.refType.isBranch || repo.isWriting {
          return false
        }
        if action == #selector(SidebarController.renameBranch(_:)) {
          sidebarCommand.isHidden = item.refType == .remoteBranch
        }
        if action == #selector(SidebarController.deleteBranch(_:)) {
          return repo.currentBranch != item.title
        }
        if action == #selector(SidebarController.mergeBranch(_:)) {
          var clickedBranch = item.title

          switch item.refType {
            case .remoteBranch:
              guard let remoteItem = item as? RemoteBranchSidebarItem
              else { return false }
              
              clickedBranch = "\(remoteItem.remoteName)/\(clickedBranch)"
            case .activeBranch:
              return false
            default:
              break
          }
          
          guard let currentBranch = repo.currentBranch
          else { return false }
          
          sidebarCommand.titleString = .merge(clickedBranch, currentBranch)
        }
        return true
      
      case #selector(SidebarController.deleteTag(_:)):
        return !repo.isWriting && (item is TagSidebarItem)
      
      case #selector(SidebarController.renameRemote(_:)),
           #selector(SidebarController.deleteRemote(_:)):
        return !repo.isWriting && (item is RemoteSidebarItem)
      
      case #selector(SidebarController.copyRemoteURL(_:)):
        return item is RemoteSidebarItem
      
      case #selector(SidebarController.popStash(_:)),
           #selector(SidebarController.applyStash(_:)),
           #selector(SidebarController.dropStash(_:)):
        return !repo.isWriting && item is StashSidebarItem
      
      case #selector(SidebarController.showSubmodule(_:)):
        return item is SubmoduleSidebarItem
      
      case #selector(SidebarController.updateSubmodule(_:)):
        return !repo.isWriting && item is SubmoduleSidebarItem
      
      default:
        return false
    }
  }
  
  func callCommand(targetItem: SidebarItem? = nil,
                   block: @escaping (SidebarItem) throws -> Void)
  {
    guard let item = targetItem ?? self.targetItem()
    else { return }
    
    repo.queue.executeOffMainThread {
      do {
        try block(item)
      }
      catch let error as NSError {
        DispatchQueue.main.async {
          guard let window = self.window
          else { return }
          let alert = NSAlert(error: error)
          
          alert.beginSheetModal(for: window, completionHandler: nil)
        }
      }
    }
  }

  func popStash()
  {
    callCommand {
      [weak self] (item) in
      guard let index = self?.stashIndex(for: item)
      else { return }
      
      try self?.repo.popStash(index: index)
    }
  }
  
  func applyStash()
  {
    callCommand {
      [weak self] (item) in
      guard let index = self?.stashIndex(for: item)
      else { return }
      
      try self?.repo.applyStash(index: index)
    }
  }
  
  func dropStash()
  {
    callCommand {
      [weak self] (item) in
      guard let index = self?.stashIndex(for: item)
      else { return }
      
      try self?.repo.dropStash(index: index)
    }
  }
}

/// Manages the main window sidebar.
class SidebarController: NSViewController, SidebarHandler
{
  @IBOutlet weak var sidebarOutline: SideBarOutlineView!
  @IBOutlet weak var sidebarDS: SideBarDataSource!
  
  @IBOutlet var branchContextMenu: NSMenu!
  @IBOutlet var remoteBranchContextMenu: NSMenu!
  @IBOutlet var remoteContextMenu: NSMenu!
  @IBOutlet var tagContextMenu: NSMenu!
  @IBOutlet var stashContextMenu: NSMenu!
  @IBOutlet var submoduleContextMenu: NSMenu!
  
  weak var repo: XTRepository!
  {
    didSet
    {
      sidebarDS.repository = repo
      observers.addObserver(forName: .XTRepositoryIndexChanged,
                            object: repo, queue: .main) {
        [weak self] (_) in
        self?.sidebarOutline.reloadItem(self?.sidebarDS.stagingItem)
      }
      observers.addObserver(forName: .XTRepositoryWorkspaceChanged,
                            object: repo, queue: .main) {
        [weak self] (_) in
        self?.sidebarOutline.reloadItem(self?.sidebarDS.stagingItem)
      }
    }
  }
  var window: NSWindow? { return view.window }
  var savedSidebarWidth: UInt = 0
  let observers = ObserverCollection()
  var amendingObserver: NSKeyValueObservation?
  
  deinit
  {
    // The timers contain references to the ds object and repository.
    sidebarDS?.stopTimers()
  }
  
  override func viewDidLoad()
  {
    sidebarOutline.floatsGroupRows = false
  
    if branchContextMenu == nil,
       let menuNib = NSNib(nibNamed: "Sidebar Menus", bundle: nil) {
      menuNib.instantiate(withOwner: self, topLevelObjects: nil)
    }
    
    let repoController = view.window!.windowController as! XTWindowController
    
    observers.addObserver(
        forName: .XTSelectedModelChanged,
        object: repoController, queue: .main) {
      [weak self] (_) in
      self?.selectedModelChanged()
    }
    amendingObserver = repoController.observe(\.isAmending) {
      [weak self] (controller, _) in
      self?.sidebarDS.setAmending(controller.isAmending)
    }
    repoController.addObserver(
        self, forKeyPath: #keyPath(XTWindowController.isAmending),
        options: [], context: nil)
  }
  
  func selectedModelChanged()
  {
    let repoController = view.window!.windowController as! XTWindowController

    if let selectedItem = sidebarOutline.item(atRow: sidebarOutline.selectedRow) {
      guard (selectedItem as? SidebarItem)?.selection?.shaToSelect !=
            repoController.selection?.shaToSelect
      else {
        return
      }
    }
    
    switch repoController.selection {
    
      case let stashChanges as StashSelection:
        let stashRoot = sidebarDS.roots[XTGroupIndex.stashes.rawValue]
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
  }
  
  func selectedBranch() -> String?
  {
    let selection = sidebarOutline.item(atRow: sidebarOutline.selectedRow)
                    as? LocalBranchSidebarItem
    
    return selection?.title
  }
  
  func selectItem(_ item: SidebarItem, group: XTGroupIndex)
  {
    sidebarOutline.expandItem(
        sidebarOutline.item(atRow: group.rawValue))
    
    let row = sidebarOutline.row(forItem: item)
    
    if row != -1 {
      sidebarOutline.selectRowIndexes(IndexSet(integer: row),
                                      byExtendingSelection: false)
    }
  }
  
  func selectItem(name: String, group: XTGroupIndex)
  {
    sidebarDS.item(named: name, inGroup: group).map {
      selectItem($0, group: group)
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
    let remotesGroup = sidebarDS.rootItem(.remotes)
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
      
      case let branchRef where branchRef.hasPrefix(BranchPrefixes.heads):
        select(branch: branchRef.removingPrefix(BranchPrefixes.heads))
      
      case let remoteRef where remoteRef.hasPrefix(BranchPrefixes.remotes):
        select(remoteBranch:
            remoteRef.removingPrefix(BranchPrefixes.remotes))
      
      case let tagRef where tagRef.hasPrefix(GitTag.tagPrefix):
        select(tag: tagRef.removingPrefix(GitTag.tagPrefix))
      
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
    let stashes = sidebarDS.roots[XTGroupIndex.stashes.rawValue]
    
    return stashes.children.index(of: item).map { UInt($0) }
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

extension SidebarController: NSMenuItemValidation
{
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
  {
    return validate(sidebarCommand: menuItem)
  }
}
