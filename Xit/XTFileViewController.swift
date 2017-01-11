import Foundation

/// View controller for the file list and detail view.
@objc
class XTFileViewController: NSViewController
{
  /// Column identifiers for the file list
  struct ColumnID
  {
    static let main = "main"
    static let staged = "change"
    static let unstaged = "unstaged"
  }
  
  /// Table cell view identifiers for the file list
  struct CellViewID
  {
    static let fileCell = "fileCell"
    static let change = "change"
    static let staged = "staged"
    static let unstaged = "unstaged"
  }

  @IBOutlet weak var headerSplitView: NSSplitView!
  @IBOutlet weak var fileSplitView: NSSplitView!
  @IBOutlet weak var leftPane: NSView!
  @IBOutlet weak var rightPane: NSView!
  @IBOutlet weak var fileListOutline: NSOutlineView!
  @IBOutlet weak var headerTabView: NSTabView!
  @IBOutlet weak var previewTabView: NSTabView!
  @IBOutlet weak var viewSelector: NSSegmentedControl!
  @IBOutlet weak var stageSelector: NSSegmentedControl!
  @IBOutlet weak var previewSelector: NSSegmentedControl!
  @IBOutlet weak var stageButtons: NSSegmentedControl!
  @IBOutlet weak var actionButton: NSPopUpButton!
  @IBOutlet weak var previewPath: NSPathControl!
  @IBOutlet weak var filePreview: QLPreviewView!
  @IBOutlet var fileChangeDS: XTFileChangesDataSource!
  @IBOutlet var fileListDS: XTFileTreeDataSource!
  @IBOutlet var headerController: XTCommitHeaderViewController!
  @IBOutlet var diffController: XTFileDiffController!
  @IBOutlet var previewController: XTPreviewController!
  @IBOutlet var textController: XTTextPreviewController!
  var commitEntryController: XTCommitEntryController!
  
  var changeImages = [UInt: NSImage]()
  var stageImages = [UInt: NSImage]()
  var contentController: XTFileContentController!
  var indexObserver: NSObjectProtocol?
  var modelObserver: NSObjectProtocol?
  
  var fileWatcher: XTFileEventStream?
  weak var lastClickedButton: NSButton?
  var doubleClickTimer: Timer?
  
  var fileListDataSource: XTFileListDataSource & NSOutlineViewDataSource
  {
    return fileListOutline.dataSource as! XTFileListDataSource &
                                          NSOutlineViewDataSource
  }
  
  var inStagingView: Bool
  {
    return (view.window?.windowController as? XTWindowController)?
           .selectedModel?.hasUnstaged ?? false
  }
  
  var modelCanCommit: Bool
  {
    return (view.window?.windowController as? XTWindowController)?
           .selectedModel?.canCommit ?? false
  }
  
  var isStaging: Bool
  {
    get
    {
      return !stageSelector.isHidden
    }
    set
    {
      stageSelector.isHidden = !newValue
    }
  }
  
  var isCommitting: Bool
  {
    get
    {
      return !actionButton.isHidden
    }
    set
    {
      headerTabView.selectTabViewItem(at: newValue ? 1 : 0)
      stageButtons.isHidden = !newValue
      actionButton.isHidden = !newValue
    }
  }
  
  var showingStaged: Bool
  {
    get
    {
      return fileListOutline.highlightedTableColumn?.identifier ==
             ColumnID.staged
    }
    set
    {
      let columnID = newValue ? ColumnID.staged : ColumnID.unstaged
      guard let column = fileListOutline.tableColumn(withIdentifier: columnID)
      else { return }
      
      fileListOutline.highlightedTableColumn = column
      fileListOutline.setNeedsDisplay()
      stageSelector.selectedSegment = newValue ? 1 : 0
      refreshPreview()
    }
  }
  
  weak var repo: XTRepository?
  {
    didSet
    {
      fileChangeDS.repository = repo
      fileListDS.repository = repo
      headerController.repository = repo
      commitEntryController.repo = repo
      indexObserver = NotificationCenter.default.addObserver(
          forName: NSNotification.Name.XTRepositoryIndexChanged,
          object: repo, queue: .main) {
        note in
        self.indexChanged(note)
      }
    }
  }
  
  deinit
  {
    [indexObserver, modelObserver].forEach {
      $0.map { NotificationCenter.default.removeObserver($0) }
    }
  }

  func windowDidLoad()
  {
    guard let controller = view.window?.windowController
                           as? XTWindowController
    else { return }
    
    fileChangeDS.winController = controller
    fileListDS.winController = controller
    headerController.winController = controller
    modelObserver = NotificationCenter.default.addObserver(
        forName: NSNotification.Name.XTSelectedModelChanged,
        object: controller, queue: .main) {
      [weak self] _ in
      self?.selectedModelChanged()
    }
  }
  
  func indexChanged(_ note: Notification)
  {
    if inStagingView {
      fileListDataSource.reload()
    }
    
    // Ideally, check to see if the selected file has changed
    if modelCanCommit {
      loadSelectedPreview()
    }
  }
  
  func reload()
  {
    fileListDataSource.reload()
  }
  
  func refreshPreview()
  {
    loadSelectedPreview()
    filePreview.refreshPreviewItem()
  }
  
  func updatePreviewPath(_ path: String, isFolder: Bool)
  {
    let components = (path as NSString).pathComponents
    let cells = components.enumerated().map {
      (index, component) -> NSPathComponentCell in
      let cell = NSPathComponentCell()
      let workspace = NSWorkspace.shared()
      
      cell.title = component
      cell.image = !isFolder && (index == components.count - 1)
          ? workspace.icon(forFileType: (component as NSString).pathExtension)
          : NSImage(named: NSImageNameFolder)
      
      return cell
    }
    
    previewPath.setPathComponentCells(cells)
  }
  
  func selectedModelChanged()
  {
    guard let controller = view.window?.windowController
                           as? XTWindowController,
          let newModel = controller.selectedModel
    else { return }
    
    if isStaging != newModel.hasUnstaged {
      isStaging = newModel.hasUnstaged
    }
    if isCommitting != newModel.canCommit {
      isCommitting = newModel.canCommit
    
      let unstagedIndex = fileListOutline.column(withIdentifier: ColumnID.unstaged)
      let stagedIndex = fileListOutline.column(withIdentifier: ColumnID.staged)
      let displayRect = NSUnionRect(fileListOutline.rect(ofColumn: unstagedIndex),
                                    fileListOutline.rect(ofColumn: stagedIndex))
      
      fileListOutline.setNeedsDisplay(displayRect)
    }
    headerController.commitSHA = newModel.shaToSelect
    refreshPreview()
  }
  
  func loadSelectedPreview()
  {
    guard let repo = repo,
          let index = fileListOutline.selectedRowIndexes.first,
          let selectedItem = fileListOutline.item(atRow: index),
          let selectedChange = fileListDataSource.fileChange(atRow: index),
          let controller = view.window?.windowController
                           as? XTWindowController
    else { return }
    
    updatePreviewPath(selectedChange.path,
                      isFolder: fileListOutline.isExpandable(selectedItem))
    contentController.load(path: selectedChange.path,
                           model: controller.selectedModel,
                           staged: showingStaged)
    
    let fullPath = repo.repoURL.path.stringByAppendingPathComponent(
                   selectedChange.path)
    
    fileWatcher = inStagingView ?
        XTFileEventStream(path: fullPath,
                          excludePaths: [],
                          queue: .main,
                          latency: 0.5) {
          _ in self.loadSelectedPreview()
        }
        : nil
  }

  // MARK: Actions

  @IBAction func changeFileListView(_: Any?)
  {
    let newDS = viewSelector.selectedSegment == 0 ? fileChangeDS : fileListDS
    let columnID = newDS.isHierarchical ? "main" : "hidden"
    
    fileListOutline.outlineTableColumn =
        fileListOutline.tableColumn(withIdentifier: columnID)
    fileListOutline.delegate = self
    fileListOutline.dataSource = newDS
    fileListOutline.reloadData()
  }

  @IBAction func stageAll(_: Any?)
  {
    try? repo?.stageAllFiles()
    showingStaged = true
  }
  
  @IBAction func unstageAll(_: Any?)
  {
    repo?.unstageAllFiles()
    showingStaged = false
  }

  @IBAction func stageUnstageAll(sender: Any?)
  {
    guard let segmentControl = sender as? NSSegmentedControl
    else { return }
    
    switch segmentControl.selectedSegment {
      case 0: unstageAll(sender)
      case 1: stageAll(sender)
      default: break
    }
  }
  
  @IBAction func showIgnored(_: Any?)
  {
  }

  @IBAction func revert(_: AnyObject)
  {
    guard let selectedRow = fileListOutline.selectedRowIndexes.first,
          let change = fileListDataSource.fileChange(atRow: selectedRow)
    else { return }
    
    let confirmAlert = NSAlert()
    
    confirmAlert.messageText = "Are you sure you want to revert changes to " +
                               "\((change.path as NSString).lastPathComponent)?"
    confirmAlert.addButton(withTitle: "Revert")
    confirmAlert.addButton(withTitle: "Cancel")
    confirmAlert.beginSheetModal(for: view.window!) {
      (response) in
      if response == NSAlertFirstButtonReturn {
        self.revertConfirmed(path: change.path)
      }
    }
  }
  
  func revertConfirmed(path: String)
  {
    do {
      try repo?.revert(file: path)
    }
    catch let error as NSError {
      let alert = NSAlert(error: error)
      
      alert.beginSheetModal(for: view.window!, completionHandler: nil)
    }
  }
  
  override open func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
  {
    guard let action = menuItem.action
    else { return false }
    
    switch action {
      case #selector(self.revert(_:)):
        guard let selectedRow = fileListOutline.selectedRowIndexes.first,
              let change = fileListDataSource.fileChange(atRow: selectedRow)
        else { return false }
        
        switch change.unstagedChange {
          case .unmodified: fallthrough  // No changes to revert
          case .untracked:               // Nothing to revert to
            return false
          default:
            return true
        }
      
      case #selector(self.showWhitespaceChanges(_:)):
        return valitadeWhitespaceMenuItem(menuItem, whitespace: .showAll)
      case #selector(self.ignoreEOLWhitespace(_:)):
        return valitadeWhitespaceMenuItem(menuItem, whitespace: .ignoreEOL)
      case #selector(self.ignoreAllWhitespace(_:)):
        return valitadeWhitespaceMenuItem(menuItem, whitespace: .ignoreAll)
      
      case #selector(self.tabWidth2(_:)):
        return validateTabMenuItem(menuItem, width: 2)
      case #selector(self.tabWidth4(_:)):
        return validateTabMenuItem(menuItem, width: 4)
      case #selector(self.tabWidth6(_:)):
        return validateTabMenuItem(menuItem, width: 6)
      case #selector(self.tabWidth8(_:)):
        return validateTabMenuItem(menuItem, width: 8)
      default:
        return true
    }
  }
  
  func valitadeWhitespaceMenuItem(_ item: NSMenuItem,
                                  whitespace: XTWhitespace) -> Bool
  {
    guard let wsController = contentController as? WhitespaceVariable
    else {
      item.state = NSOffState
      return false
    }
    
    item.state = (wsController.whitespace == whitespace) ? NSOnState : NSOffState
    return true
  }
  
  func validateTabMenuItem(_ item: NSMenuItem, width: UInt) -> Bool
  {
    guard let tabController = contentController as? TabWidthVariable
    else {
      item.state = NSOffState
      return false
    }
    
    item.state = (tabController.tabWidth == width) ? NSOnState : NSOffState
    return true
  }
  
  @IBAction func showWhitespaceChanges(_ sender: Any?)
  {
    setWhitespace(.showAll)
  }
  
  @IBAction func ignoreEOLWhitespace(_ sender: Any?)
  {
    setWhitespace(.ignoreEOL)
  }
  
  @IBAction func ignoreAllWhitespace(_ sender: Any?)
  {
    setWhitespace(.ignoreAll)
  }
  
  @IBAction func tabWidth2(_ sender: Any?)
  {
    setTabWidth(2)
  }
  
  @IBAction func tabWidth4(_ sender: Any?)
  {
    setTabWidth(4)
  }
  
  @IBAction func tabWidth6(_ sender: Any?)
  {
    setTabWidth(6)
  }
  
  @IBAction func tabWidth8(_ sender: Any?)
  {
    setTabWidth(8)
  }
  
  func setWhitespace(_ setting: XTWhitespace)
  {
    guard let wsController = contentController as? WhitespaceVariable
    else { return }
    
    wsController.whitespace = setting
  }
  
  func setTabWidth(_ tabWidth: UInt)
  {
    guard let tabController = contentController as? TabWidthVariable
    else { return }
    
    tabController.tabWidth = tabWidth
  }
}

extension XTFileViewController: NSOutlineViewDelegate
{
  private func image(forChange change: XitChange) -> NSImage?
  {
    return changeImages[change.rawValue]
  }

  private func displayChange(forChange change: XitChange,
                             otherChange: XitChange) -> XitChange
  {
    return (change == .unmodified) && (otherChange != .unmodified)
           ? .mixed : change
  }

  private func stagingImage(forChange change: XitChange,
                            otherChange: XitChange) -> NSImage?
  {
    let change = displayChange(forChange:change, otherChange:otherChange)
    
    return stageImages[change.rawValue]
  }

  private func tableButtonView(_ identifier: String,
                               change: XitChange,
                               otherChange: XitChange,
                               row: Int) -> XTTableButtonView
  {
    let cell = fileListOutline.make(withIdentifier: identifier, owner: self)
               as! XTTableButtonView
    
    if let button = cell.button {
      (button.cell as! NSButtonCell).imageDimsWhenDisabled = false
      if modelCanCommit {
        button.image = stagingImage(forChange:change,
                                    otherChange:otherChange)
        button.isEnabled = displayChange(forChange:change,
                                         otherChange:otherChange)
                           != .mixed
      }
      else {
        button.image = image(forChange:change)
        button.isEnabled = false
      }
    }
    cell.row = row
    return cell
  }

  func outlineView(_ outlineView: NSOutlineView,
                   viewFor tableColumn: NSTableColumn?,
                   item: Any) -> NSView?
  {
    guard let columnID = tableColumn?.identifier
    else { return nil }
    let dataSource = fileListDataSource
    let change = dataSource.change(forItem: item)
    
    switch columnID {
      
      case ColumnID.main:
        guard let cell = outlineView.make(withIdentifier: CellViewID.fileCell,
                                          owner: self) as? XTFileCellView
        else { return nil }
      
        let path = dataSource.path(forItem: item) as NSString
      
        cell.imageView?.image = dataSource.outlineView!(outlineView,
                                                       isItemExpandable: item)
                                ? NSImage(named: NSImageNameFolder)
                                : NSWorkspace.shared()
                                  .icon(forFileType: path.pathExtension)
        cell.textField?.stringValue = path.lastPathComponent
      
        var textColor: NSColor!
      
        if change == .deleted {
          textColor = NSColor.disabledControlTextColor
        }
        else if outlineView.isRowSelected(outlineView.row(forItem: item)) {
          textColor = NSColor.selectedTextColor
        }
        else {
          textColor = NSColor.textColor
        }
        cell.textField?.textColor = textColor
        cell.change = change
        return cell
      
      case ColumnID.staged:
        if inStagingView {
          return tableButtonView(
              CellViewID.staged,
              change: change,
              otherChange: dataSource.unstagedChange(forItem: item),
              row: outlineView.row(forItem:item))
        }
        else {
          guard let cell = outlineView.make(withIdentifier: CellViewID.change,
                                            owner: self)
                           as? NSTableCellView
          else { return nil }
          
          cell.imageView?.image = image(forChange:change)
          return cell
        }
      
      case ColumnID.unstaged:
        if inStagingView {
          return tableButtonView(
              CellViewID.unstaged,
              change: dataSource.unstagedChange(forItem: item),
              otherChange: change,
              row: outlineView.row(forItem: item))
        }
        else {
          return nil
        }
      
      default:
        return nil
    }
  }
  
  func outlineView(_ outlineView: NSOutlineView,
                   rowViewForItem item: Any) -> NSTableRowView?
  {
    return FileRowView()
  }
  
  func outlineView(_ outlineView: NSOutlineView,
                   didAdd rowView: NSTableRowView,
                   forRow row: Int)
  {
    if let fileRowView = rowView as? FileRowView {
      fileRowView.outlineView = fileListOutline
    }
  }
}

extension XTFileViewController: NSSplitViewDelegate
{
  public func splitView(_ splitView: NSSplitView,
                        shouldAdjustSizeOfSubview view: NSView) -> Bool
  {
    switch splitView {
      case headerSplitView:
        return view != headerController.view
      case fileSplitView:
        return view != leftPane
      default:
        return true
    }
  }
}
