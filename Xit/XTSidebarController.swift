import Cocoa

// Command handling extracted for testability
protocol SidebarHandler
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
      (item) in
      guard let index = self.stashIndex(for: item)
      else { return }
      
      try self.repo.popStash(index: index)
    }
  }
  
  func applyStash()
  {
    callCommand(errorString: "Apply stash failed") {
      (item) in
      guard let index = self.stashIndex(for: item)
      else { return }
      
      try self.repo.applyStash(index: index)
    }
  }
  
  func dropStash()
  {
    callCommand(errorString: "Drop stash failed") {
      (item) in
      guard let index = self.stashIndex(for: item)
      else { return }
      
      try self.repo.dropStash(index: index)
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
      observers.addObserver(
          forName: NSNotification.Name.XTRepositoryIndexChanged,
          object: repo, queue: .main) {
        [weak self] (_) in
        self?.sidebarOutline.reloadItem(self?.sidebarDS.stagingItem)
      }
      observers.addObserver(
          forName: .XTRepositoryWorkspaceChanged, object: repo, queue: .main) {
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
        (item) in
        _ = self.repo.deleteBranch(item.title)
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
  
  // MARK: Actions
  
  @IBAction func sidebarItemRenamed(_ sender: Any)
  {
    guard let textField = sender as? NSTextField,
          let cellView = textField.superview as? XTSidebarTableCellView,
          let editedItem = cellView.item
    else { return }
    
    let newName = textField.stringValue
    let oldName = editedItem.title
    guard newName != oldName
    else { return }
    
    if editedItem.refType == .remote {
      try? repo.renameRemote(old: oldName, new: newName)
    }
  }
  
  @IBAction func checkOutBranch(_ sender: Any?)
  {
    callCommand(errorString: "Checkout failed") {
      (item) in
      do {
        try self.repo.checkout(branch: item.title)
      }
      catch let error as NSError
            where error.domain == GTGitErrorDomain &&
                  error.gitError == GIT_ECONFLICT {
        DispatchQueue.main.async {
          let alert = NSAlert()
          
          alert.messageText =
              "Checkout failed because of a conflict with local changes."
          alert.informativeText =
              "Revert or stash your changes and try again."
          alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
        }
      }
    }
  }
  
  @IBAction func renameBranch(_ sender: Any?)
  {
    guard let selectedItem = targetItem(),
          let controller = view.window?.windowController as? XTWindowController
    else { return }
    
    controller.startRenameBranch(selectedItem.title)
  }
  
  @IBAction func mergeBranch(_ sender: Any?)
  {
    guard let selectedItem = targetItem() as? XTBranchItem,
          let branch = XTBranch(name: selectedItem.title, repository: repo)
    else { return }
    
    repo.queue.executeOffMainThread {
      [weak self] in
      do {
        try self?.repo.merge(branch: branch)
      }
      catch let repoError as XTRepository.Error {
        DispatchQueue.main.async {
          guard let window = self?.view.window
          else { return }
          let alert = NSAlert()
          
          alert.messageText = repoError.message
          alert.beginSheetModal(for: window, completionHandler: nil)
        }
      }
      catch {
        NSLog("Unexpected error")
      }
    }
  }
  
  @objc(deleteBranch:)
  @IBAction func deleteBranch(_ sender: Any?)
  {
    guard let item = targetItem()
    else { return }
    
    deleteBranch(item: item)
  }
  
  @IBAction func deleteTag(_ sender: Any?)
  {
    guard let item = targetItem()
    else { return }
    
    confirmDelete(kind: "tag", name: item.title) {
      self.callCommand(errorString: "Delete tag failed", targetItem: item) {
        (item) in
        try self.repo.deleteTag(name: item.title)
      }
    }
  }
  
  @IBAction func renameRemote(_ sender: Any?)
  {
    editSelectedRow()
  }
  
  @IBAction func deleteRemote(_ sender: Any?)
  {
    callCommand(errorString: "Delete remote failed") {
      (item) in
      try self.repo.delete(remote: item.title)
    }
  }
  
  @IBAction func copyRemoteURL(_ sender: Any?)
  {
    guard let item = targetItem()
    else { return }
    let remoteName = "remote.\(item.title).url"
    guard let remoteURL = repo.config.urlString(forRemote: remoteName)
    else { return }
    let pasteboard = NSPasteboard.general
    
    pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
    pasteboard.setString(remoteURL, forType: NSPasteboard.PasteboardType.string)
  }
  
  @IBAction func popStash(_ sender: Any?)
  {
    popStash()
  }
  
  @IBAction func applyStash(_ sender: Any?)
  {
    applyStash()
  }
  
  @IBAction func dropStash(_ sender: Any?)
  {
    dropStash()
  }
}
