import Cocoa

/// Manages the main window sidebar.
class XTSidebarController: NSViewController
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
      sidebarDS.repo = repo
      NotificationCenter.default.addObserver(
          forName: NSNotification.Name.XTRepositoryIndexChanged,
          object: repo, queue: OperationQueue.main) {
        (notification) in
        self.sidebarOutline.reloadItem(self.sidebarDS.stagingItem)
      }
    }
  }
  var savedSidebarWidth: UInt = 0
  
  deinit
  {
    // The timers contain references to the ds object and repository.
    sidebarDS?.stopTimers()
    NotificationCenter.default.removeObserver(self)
  }
  
  override func viewDidLoad()
  {
    sidebarOutline.floatsGroupRows = false
  
    if branchContextMenu == nil,
       let menuNib = NSNib(nibNamed: "HistoryView Menus", bundle: nil) {
      menuNib.instantiate(withOwner: self, topLevelObjects: nil)
    }
  }
  
  func reload()
  {
    sidebarDS.reload()
  }
  
  override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
  {
    guard let action = menuItem.action,
          let item = targetItem()
    else { return false }
    
    switch action {
      case #selector(XTSidebarController.checkOutBranch(_:)): fallthrough
      case #selector(XTSidebarController.renameBranch(_:)): fallthrough
      case #selector(XTSidebarController.mergeBranch(_:)): fallthrough
      case #selector(XTSidebarController.deleteBranch(_:)):
        if ((item.refType != .branch) && (item.refType != .remoteBranch)) ||
           repo.isWriting {
          return false
        }
        if action == #selector(XTSidebarController.deleteBranch(_:)) {
          return repo.currentBranch != item.title
        }
        if action == #selector(XTSidebarController.mergeBranch(_:)) {
          menuItem.attributedTitle = nil
          menuItem.title = "Merge"
          
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
          
          let menuFontAttributes = [NSFontAttributeName: NSFont.menuFont(ofSize: 0)]
          let obliqueAttributes = [NSObliquenessAttributeName: 0.15]
          
          if let mergeTitle = NSAttributedString.init(
              format: "Merge @~1 into @~2",
              placeholders: ["@~1", "@~2"],
              replacements: [clickedBranch, currentBranch],
              attributes: menuFontAttributes,
              replacementAttributes: obliqueAttributes) {
            menuItem.attributedTitle = mergeTitle
          }
        }
        return true
      default:
        return false
    }
  }
  
  func selectedBranch() -> String?
  {
    let selection = sidebarOutline.item(atRow: sidebarOutline.selectedRow)
                    as? XTLocalBranchItem
    
    return selection?.title
  }
  
  @objc(selectBranch:)
  func select(branch: String)
  {
    guard let branchItem = sidebarDS.item(named: branch, inGroup: .branches)
    else { return }
    
    sidebarOutline.expandItem(
        sidebarOutline.item(atRow: XTGroupIndex.branches.rawValue))
    
    let row = sidebarOutline.row(forItem: branchItem)
    
    if row != -1 {
      sidebarOutline.selectRowIndexes(IndexSet(integer: row),
                                      byExtendingSelection: false)
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
  
  func editSelectedRow()
  {
    sidebarOutline.editColumn(0, row: targetRow(), with: nil, select: true)
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
      if response == NSAlertFirstButtonReturn {
        onConfirm()
      }
    }
  }
  
  func callCMBlock(errorString: String,
                   targetItem: XTSideBarItem? = nil,
                   block: @escaping (XTSideBarItem, UInt) throws -> Void)
  {
    guard let item = targetItem ?? self.targetItem(),
          let parent = sidebarOutline.parent(forItem: item) as? XTSideBarItem,
          let index = parent.children.index(of: item)
    else { return }
    
    repo.executeOffMainThread {
      do {
        try block(item, UInt(index))
      }
      catch {
        // report error
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
      repo.renameRemote(oldName, to: newName)
    }
  }
  
  @IBAction func checkOutBranch(_ sender: Any?)
  {
    callCMBlock(errorString: "Checkout failed") {
      (item, index) in
      try self.repo.checkout(item.title)
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
    guard let branch = selectedBranch()
    else { return }
    
    _ = try? repo.merge(branch)
  }
  
  @IBAction func deleteBranch(_ sender: Any?)
  {
    guard let item = targetItem()
    else { return }
    
    confirmDelete(kind: "branch", name: item.title) {
      self.callCMBlock(errorString: "Delete branch failed", targetItem: item) {
        (item, index) in
        try self.repo.deleteBranch(item.title)
      }
    }
  }
  
  @IBAction func deleteTag(_ sender: Any?)
  {
    guard let item = targetItem()
    else { return }
    
    confirmDelete(kind: "tag", name: item.title) {
      self.callCMBlock(errorString: "Delete tag failed", targetItem: item) {
        (item, index) in
        try self.repo.deleteTag(item.title)
      }
    }
  }
  
  @IBAction func renameRemote(_ sender: Any?)
  {
    editSelectedRow()
  }
  
  @IBAction func deleteRemote(_ sender: Any?)
  {
    callCMBlock(errorString: "Delete remote failed") {
      (item, index) in
      try self.repo.deleteRemote(item.title)
    }
  }
  
  @IBAction func copyRemoteURL(_ sender: Any?)
  {
    guard let item = targetItem()
    else { return }
    let remoteName = "remote.\(item.title).url"
    let remoteURL = repo.urlString(forRemote: remoteName)
    let pasteboard = NSPasteboard.general()
    
    pasteboard.declareTypes([NSStringPboardType], owner: nil)
    pasteboard.setString(remoteURL, forType: NSStringPboardType)
  }
  
  @IBAction func popStash(_ sender: Any?)
  {
    callCMBlock(errorString: "Pop stash failed") {
      (item, index) in
      try self.repo.popStashIndex(index)
    }
  }
  
  @IBAction func applyStash(_ sender: Any?)
  {
    callCMBlock(errorString: "Apply stash failed") {
      (item, index) in
      try self.repo.applyStashIndex(index)
    }
  }
  
  @IBAction func dropStash(_ sender: Any?)
  {
    callCMBlock(errorString: "Drop stash failed") {
      (item, index) in
      try self.repo.dropStashIndex(index)
    }
  }
}
