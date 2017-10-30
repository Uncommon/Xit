import Cocoa

// Command handling extracted for testability
protocol SidebarHandler: class
{
  var repo: XTRepository! { get }
  var window: NSWindow? { get }
  
  func targetItem() -> XTSideBarItem?
  func stashIndex(for item: XTSideBarItem) -> UInt?
}

extension SidebarHandler
{
  func validate(sidebarCommand: NSMenuItem) -> Bool
  {
    guard let action = sidebarCommand.action,
          let item = targetItem()
    else { return false }
    
    switch action {
      
      case #selector(XTSidebarController.checkOutBranch(_:)),
           #selector(XTSidebarController.renameBranch(_:)),
           #selector(XTSidebarController.mergeBranch(_:)),
           #selector(XTSidebarController.deleteBranch(_:)):
        if ((item.refType != .branch) && (item.refType != .remoteBranch)) ||
            repo.isWriting {
          return false
        }
        if action == #selector(XTSidebarController.deleteBranch(_:)) {
          return repo.currentBranch != item.title
        }
        if action == #selector(XTSidebarController.mergeBranch(_:)) {
          sidebarCommand.attributedTitle = nil
          sidebarCommand.title = "Merge"
          
          var clickedBranch = item.title
          guard let currentBranch = repo.currentBranch
          else { return false }
          
          if item.refType == .remoteBranch {
            guard let remoteItem = item as? XTRemoteBranchItem
            else { return false }
            
            clickedBranch = "\(remoteItem.remote)/\(clickedBranch)"
          }
          else if item.refType == .branch {
            if clickedBranch == currentBranch {
              return false
            }
          }
          else {
            return false
          }
          
          let menuFontAttributes = [NSAttributedStringKey.font:
                                    NSFont.menuFont(ofSize: 0)]
          let obliqueAttributes = [NSAttributedStringKey.obliqueness: 0.15]
          
          if let mergeTitle = NSAttributedString.init(
              format: "Merge @~1 into @~2",
              placeholders: ["@~1", "@~2"],
              replacements: [clickedBranch, currentBranch],
              attributes: menuFontAttributes,
              replacementAttributes: obliqueAttributes) {
            sidebarCommand.attributedTitle = mergeTitle
          }
        }
        return true
      
      case #selector(XTSidebarController.deleteTag(_:)):
        return !repo.isWriting && (item is XTTagItem)
      
      case #selector(XTSidebarController.renameRemote(_:)),
           #selector(XTSidebarController.deleteRemote(_:)):
        return !repo.isWriting && (item is XTRemoteItem)
      
      case #selector(XTSidebarController.copyRemoteURL(_:)):
        return item is XTRemoteItem
      
      case #selector(XTSidebarController.popStash(_:)),
           #selector(XTSidebarController.applyStash(_:)),
           #selector(XTSidebarController.dropStash(_:)):
        return !repo.isWriting && item is XTStashItem
      
      default:
        return false
    }
  }
  
  func callCommand(errorString: String,
                   targetItem: XTSideBarItem? = nil,
                   block: @escaping (XTSideBarItem) throws -> Void)
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
    callCommand(errorString: "Pop stash failed") {
      [weak self] (item) in
      guard let index = self?.stashIndex(for: item)
      else { return }
      
      try self?.repo.popStash(index: index)
    }
  }
  
  func applyStash()
  {
    callCommand(errorString: "Apply stash failed") {
      [weak self] (item) in
      guard let index = self?.stashIndex(for: item)
      else { return }
      
      try self?.repo.applyStash(index: index)
    }
  }
  
  func dropStash()
  {
    callCommand(errorString: "Drop stash failed") {
      [weak self] (item) in
      guard let index = self?.stashIndex(for: item)
      else { return }
      
      try self?.repo.dropStash(index: index)
    }
  }
}

/// Manages the main window sidebar.
class XTSidebarController: NSViewController, SidebarHandler
{
  @IBOutlet weak var sidebarOutline: SideBarOutlineView!
  @IBOutlet weak var sidebarDS: XTSideBarDataSource!
  
  @IBOutlet var branchContextMenu: NSMenu!
  @IBOutlet var remoteContextMenu: NSMenu!
  @IBOutlet var tagContextMenu: NSMenu!
  @IBOutlet var stashContextMenu: NSMenu!
  
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
  
  deinit
  {
    // The timers contain references to the ds object and repository.
    sidebarDS?.stopTimers()
  }
  
  override func viewDidLoad()
  {
    sidebarOutline.floatsGroupRows = false
  
    if branchContextMenu == nil,
       let menuNib = NSNib(nibNamed: NSNib.Name(rawValue: "HistoryView Menus"),
                           bundle: nil) {
      menuNib.instantiate(withOwner: self, topLevelObjects: nil)
    }
    
    let repoController = view.window!.windowController as! XTWindowController
    
    observers.addObserver(
        forName: .XTSelectedModelChanged,
        object: repoController, queue: .main) {
      [weak self] (_) in
      self?.selectedModelChanged()
    }
  }
  
  func selectedModelChanged()
  {
    let repoController = view.window!.windowController as! XTWindowController

    switch repoController.selectedModel {
    
      case let stashChanges as StashChanges:
        let stashRoot = sidebarDS.roots[XTGroupIndex.stashes.rawValue]
        guard let stashItem = stashRoot.children.first(where: {
          $0.model.map({ (model) in model == stashChanges }) ?? false
        })
        else { break }
        
        self.sidebarOutline.selectRowIndexes(
            IndexSet(integer: sidebarOutline.row(forItem: stashItem)),
            byExtendingSelection: false)
      
      case let commitChanges as CommitChanges:
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
  
  override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
  {
    return validate(sidebarCommand: menuItem)
  }
  
  func selectedBranch() -> String?
  {
    let selection = sidebarOutline.item(atRow: sidebarOutline.selectedRow)
                    as? XTLocalBranchItem
    
    return selection?.title
  }
  
  func selectItem(_ item: XTSideBarItem, group: XTGroupIndex)
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
    let slices = remoteBranch.characters.split(separator: "/", maxSplits: 1)
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
      
      case let branchRef where branchRef.hasPrefix(XTLocalBranch.headsPrefix):
        select(branch: branchRef.removingPrefix(XTLocalBranch.headsPrefix))
      
      case let remoteRef where remoteRef.hasPrefix(XTRemoteBranch.remotesPrefix):
        select(remoteBranch:
            remoteRef.removingPrefix(XTRemoteBranch.remotesPrefix))
      
      case let tagRef where tagRef.hasPrefix(XTTag.tagPrefix):
        select(tag: tagRef.removingPrefix(XTTag.tagPrefix))
      
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
  
  func targetItem() -> XTSideBarItem?
  {
    return sidebarOutline.item(atRow: targetRow()) as? XTSideBarItem
  }
  
  func stashIndex(for item: XTSideBarItem) -> UInt?
  {
    let stashes = sidebarDS.roots[XTGroupIndex.stashes.rawValue]
    
    return stashes.children.index(of: item).map { UInt($0) }
  }
  
  func editSelectedRow()
  {
    sidebarOutline.editColumn(0, row: targetRow(), with: nil, select: true)
  }
  
  func deleteBranch(item: XTSideBarItem)
  {
    confirmDelete(kind: "branch", name: item.title) {
      self.callCommand(errorString: "Delete branch failed", targetItem: item) {
        [weak self] (item) in
        _ = self?.repo.deleteBranch(item.title)
      }
    }
  }
  
  func confirmDelete(kind: String, name: String,
                     onConfirm: @escaping () -> Void)
  {
    let alert = NSAlert.init()
    
    alert.messageText = "Delete the \(kind) “\(name)”?"
    alert.addButton(withTitle: "Delete")
    alert.addButton(withTitle: "Cancel")
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
