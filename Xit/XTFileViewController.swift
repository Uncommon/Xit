import Foundation
import Quartz

/// Interface for a controller that displays file content in some form.
protocol XTFileContentController
{
  /// Clears the display for when nothing is selected.
  func clear()
  /// Displays the content from the given file model.
  /// - parameter path: The repository-relative file path.
  /// - parameter model: The model to read data from.
  /// - parameter staged: Whether to show staged content.
  func load(path: String!, model: XTFileChangesModel!, staged: Bool)
  /// True if the controller has content loaded.
  var isLoaded: Bool { get }
}

@objc
protocol WhitespaceVariable
{
  var whitespace: XTWhitespace { get set }
}

@objc
protocol TabWidthVariable
{
  var tabWidth: UInt { get set }
}

/// View controller for the file list and detail view.
class XTFileViewController: NSViewController
{
  /// Column identifiers for the file list
  struct ColumnID
  {
    static let main = "main"
    static let staged = "change"
    static let unstaged = "unstaged"
    static let hidden = "hidden"
  }
  
  /// Table cell view identifiers for the file list
  struct CellViewID
  {
    static let fileCell = "fileCell"
    static let change = "change"
    static let staged = "staged"
    static let unstaged = "unstaged"
  }
  
  /// Preview tab identifiers
  struct TabID
  {
    static let diff = "diff"
    static let blame = "blame"
    static let text = "text"
    static let preview = "preview"
    
    static let allIDs = [ diff, blame, text, preview ]
  }

  @IBOutlet weak var headerSplitView: NSSplitView!
  @IBOutlet weak var fileSplitView: NSSplitView!
  @IBOutlet weak var leftPane: NSView!
  @IBOutlet weak var fileListOutline: NSOutlineView!
  @IBOutlet weak var headerTabView: NSTabView!
  @IBOutlet weak var previewTabView: NSTabView!
  @IBOutlet weak var viewSelector: NSSegmentedControl!
  @IBOutlet weak var stageSelector: NSSegmentedControl!
  @IBOutlet weak var stageButtons: NSSegmentedControl!
  @IBOutlet weak var actionButton: NSPopUpButton!
  @IBOutlet weak var previewPath: NSPathControl!
  @IBOutlet weak var filePreview: QLPreviewView!
  @IBOutlet var fileChangeDS: XTFileChangesDataSource!
  @IBOutlet var fileTreeDS: FileTreeDataSource!
  @IBOutlet var headerController: CommitHeaderViewController!
  @IBOutlet var diffController: XTFileDiffController!
  @IBOutlet var blameController: BlameViewController!
  @IBOutlet var previewController: XTPreviewController!
  @IBOutlet var textController: XTTextPreviewController!
  var commitEntryController: XTCommitEntryController!
  
  var changeImages = [XitChange: NSImage]()
  var stageImages = [XitChange: NSImage]()
  var contentController: XTFileContentController!
  let observers = ObserverCollection()
  
  var fileWatcher: FileEventStream?
  weak var lastClickedButton: NSButton?
  var doubleClickTimer: Timer?
  var indexTimer: Timer?
  
  var contentControllers: [XTFileContentController]
  {
    return  [diffController, blameController,
             textController, previewController]
  }
  
  var fileListDataSource: FileListDataSource & NSOutlineViewDataSource
  {
    return fileListOutline.dataSource as! FileListDataSource &
                                          NSOutlineViewDataSource
  }
  
  var inStagingView: Bool
  {
    return (view.window?.windowController as? RepositoryController)?
           .selectedModel?.hasUnstaged ?? false
  }
  
  var modelCanCommit: Bool
  {
    return (view.window?.windowController as? RepositoryController)?
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
      fileTreeDS.repository = repo
      headerController.repository = repo
      commitEntryController.repo = repo
      observers.addObserver(
          forName: NSNotification.Name.XTRepositoryIndexChanged,
          object: repo, queue: .main) {
        [weak self] note in
        self?.indexChanged(note)
      }
    }
  }
  
  deinit
  {
    indexTimer.map { $0.invalidate() }
  }

  func windowDidLoad()
  {
    guard let controller = view.window?.windowController
                           as? XTWindowController
    else { return }
    
    fileChangeDS.repoController = controller
    fileTreeDS.repoController = controller
    observers.addObserver(
        forName: NSNotification.Name.XTSelectedModelChanged,
        object: controller, queue: .main) {
      [weak self] _ in
      self?.selectedModelChanged()
    }
  }
  
  override func loadView()
  {
    super.loadView()
    
    changeImages = [
        .added: NSImage(named:"added")!,
        .untracked: NSImage(named:"added")!,
        .copied: NSImage(named:"copied")!,
        .deleted: NSImage(named:"deleted")!,
        .modified: NSImage(named:"modified")!,
        .renamed: NSImage(named:"renamed")!,
        .mixed: NSImage(named:"mixed")!,
        ]
    stageImages = [
        .added: NSImage(named:"add")!,
        .untracked: NSImage(named:"add")!,
        .deleted: NSImage(named:"delete")!,
        .modified: NSImage(named:"modify")!,
        .mixed: NSImage(named:"mixed")!,
        .conflict: NSImage(named:"conflict")!,
        ]
    
    fileListOutline.highlightedTableColumn =
        fileListOutline.tableColumn(withIdentifier: ColumnID.staged)
    fileListOutline.sizeToFit()
    contentController = diffController
    
    observers.addObserver(
        forName: NSNotification.Name.NSOutlineViewSelectionDidChange,
        object: fileListOutline,
        queue: nil) {
      [weak self] _ in
      self?.refreshPreview()
    }
    observers.addObserver(
        forName: .XTHeaderResized,
        object: headerController,
        queue: nil) {
      [weak self] note in
      guard let newHeight = (note.userInfo?[CommitHeaderViewController.headerHeightKey]
                             as? NSNumber)?.floatValue
      else { return }
      
      self?.headerSplitView.animate(position:CGFloat(newHeight),
                                    ofDividerAtIndex:0)
    }
    
    commitEntryController = XTCommitEntryController(
        nibName: "XTCommitEntryController", bundle: nil)!
    if repo != nil {
      commitEntryController.repo = repo
    }
    headerTabView.tabViewItems[1].view = commitEntryController.view
    previewPath.setPathComponentCells([])
    diffController.stagingDelegate = self
  }
  
  func indexChanged(_ note: Notification)
  {
    // Reading the index too soon can yield incorrect results.
    let indexDelay: TimeInterval = 0.125
    
    if let timer = indexTimer {
      timer.fireDate = Date(timeIntervalSinceNow: indexDelay)
    }
    else {
      indexTimer = Timer.scheduledTimer(withTimeInterval: indexDelay,
                                        repeats: false) {
        [weak self] (timer) in
        self?.fileListDataSource.reload()
        self?.indexTimer = nil
      }
    }
    
    // Ideally, check to see if the selected file has changed
    if modelCanCommit {
      loadSelectedPreview(force: true)
    }
  }
  
  func reload()
  {
    fileListDataSource.reload()
  }
  
  func refreshPreview()
  {
    loadSelectedPreview(force: true)
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
                           as? RepositoryController,
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
    clearPreviews()
    refreshPreview()
  }
  
  func loadSelectedPreview(force: Bool = false)
  {
    guard !contentController.isLoaded || force
    else { return }
    
    guard let repo = repo,
          let index = fileListOutline.selectedRowIndexes.first,
          let selectedItem = fileListOutline.item(atRow: index),
          let selectedChange = self.selectedChange(),
          let controller = view.window?.windowController
                           as? RepositoryController
    else { return }
    
    updatePreviewPath(selectedChange.path,
                      isFolder: fileListOutline.isExpandable(selectedItem))
    contentController.load(path: selectedChange.path,
                           model: controller.selectedModel,
                           staged: showingStaged)
    
    let fullPath = repo.repoURL.path.appending(
                      pathComponent: selectedChange.path)
    
    fileWatcher = inStagingView ?
        FileEventStream(path: fullPath,
                        excludePaths: [],
                        queue: .main,
                        latency: 0.5) {
          [weak self] (_) in self?.loadSelectedPreview(force: true)
        }
        : nil
  }
  
  func selectedChange() -> XTFileChange?
  {
    guard let index = fileListOutline.selectedRowIndexes.first
    else { return nil }
    
    return fileListDataSource.fileChange(at: index)
  }
  
  func selectRow(from button: NSButton)
  {
    guard let row = (button.superview as? TableButtonView)?.row
    else { return }
    let indexes = IndexSet(integer: row)
    
    fileListOutline.selectRowIndexes(indexes,
                                     byExtendingSelection: false)
    view.window?.makeFirstResponder(fileListOutline)
  }
  
  func selectRow(from button: NSButton, staged: Bool)
  {
    selectRow(from: button)
    showingStaged = staged
  }
  
  func path(from button: NSButton) -> String?
  {
    guard let row = (button.superview as? TableButtonView)?.row,
          let change = fileListDataSource.fileChange(at: row)
    else { return nil }
    
    return change.path
  }
  
  func checkDoubleClick(_ button: NSButton) -> Bool
  {
    if let last = lastClickedButton,
       let event = NSApp.currentEvent,
       (last == button) && (event.clickCount > 1) {
      lastClickedButton = nil
      return true
    }
    else {
      lastClickedButton = button
      return false
    }
  }
  
  func click(button: NSButton, staging: Bool)
  {
    if modelCanCommit && checkDoubleClick(button),
       let path = path(from: button) {
      button.isEnabled = false
      if staging {
        _ = try? repo?.stageFile(path)
      }
      else {
        _ = try? repo?.unstageFile(path)
      }
      selectRow(from: button, staged: staging)
      NotificationCenter.default.post(
          name: NSNotification.Name.XTRepositoryIndexChanged,
          object: repo)
    }
    else {
      selectRow(from: button, staged: !staging)
    }
  }

  func clearPreviews()
  {
    contentControllers.forEach { $0.clear() }
  }
  
  func clear()
  {
    contentController.clear()
    previewPath.setPathComponentCells([])
  }
  
  func revert(path: String)
  {
    let confirmAlert = NSAlert()
    let status = try? repo!.status(file: path)
    
    confirmAlert.messageText = "Are you sure you want to revert changes to " +
                               "\((path as NSString).lastPathComponent)?"
    if status?.0 == .untracked {
      confirmAlert.informativeText = "The new file will be deleted."
    }
    confirmAlert.addButton(withTitle: "Revert")
    confirmAlert.addButton(withTitle: "Cancel")
    confirmAlert.beginSheetModal(for: view.window!) {
      (response) in
      if response == NSAlertFirstButtonReturn {
        self.revertConfirmed(path: path)
      }
    }
  }

  func displayAlert(error: NSError)
  {
    let alert = NSAlert(error: error)
    
    alert.beginSheetModal(for: view.window!, completionHandler: nil)
  }
  
  func displayRepositoryAlert(error: XTRepository.Error)
  {
    let alert = NSAlert()
    
    alert.messageText = error.message
    alert.beginSheetModal(for: view.window!, completionHandler: nil)
  }

  // MARK: Actions

  @IBAction func changeStageView(_ sender: Any?)
  {
    guard let segmentedControl = sender as? NSSegmentedControl
    else { return }
    
    showingStaged = segmentedControl.selectedSegment == 1
  }

  @IBAction func stageClicked(_ sender: Any?)
  {
    guard let button = sender as? NSButton
    else { return }
  
    click(button: button, staging: true)
  }
  
  @IBAction func unstageClicked(_ sender: Any?)
  {
    guard let button = sender as? NSButton
    else { return }
    
    click(button: button, staging: false)
  }

  @IBAction func changeFileListView(_: Any?)
  {
    let newDS = (viewSelector.selectedSegment == 0 ? fileChangeDS : fileTreeDS)
                as FileListDataSource & NSOutlineViewDataSource
    let columnID = newDS.hierarchical ? ColumnID.main : ColumnID.hidden
    
    fileListOutline.outlineTableColumn =
        fileListOutline.tableColumn(withIdentifier: columnID)
    fileListOutline.delegate = self
    fileListOutline.dataSource = newDS
    if newDS.outlineView!(fileListOutline, numberOfChildrenOfItem: nil) == 0 {
      newDS.reload()
    }
    else {
      fileListOutline.reloadData()
    }
  }
  
  @IBAction func changeContentView(_ sender: Any?)
  {
    guard let segmentedControl = sender as? NSSegmentedControl
    else { return }
    
    let selection = segmentedControl.selectedSegment
    
    previewTabView.selectTabViewItem(withIdentifier: TabID.allIDs[selection])
    contentController = contentControllers[selection]
    loadSelectedPreview()
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

  @IBAction func stageUnstageAll(_ sender: Any?)
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
    guard let change = selectedChange()
    else { return }
    
    revert(path: change.path)
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
        guard let change = selectedChange()
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

// MARK: NSOutlineViewDelegate
extension XTFileViewController: NSOutlineViewDelegate
{
  private func image(forChange change: XitChange) -> NSImage?
  {
    return changeImages[change]
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
    
    return stageImages[change]
  }

  private func tableButtonView(_ identifier: String,
                               change: XitChange,
                               otherChange: XitChange,
                               row: Int) -> TableButtonView
  {
    let cellView = fileListOutline.make(withIdentifier: identifier, owner: self)
                   as! TableButtonView
    let button = cellView.button!
    let displayChange = self.displayChange(forChange:change,
                                           otherChange:otherChange)
    
    (button.cell as! NSButtonCell).imageDimsWhenDisabled = false
    button.isEnabled = displayChange != .mixed
    button.image = modelCanCommit
        ? stagingImage(forChange:change, otherChange:otherChange)
        : image(forChange:change)
    cellView.row = row
    return cellView
  }

  func outlineView(_ outlineView: NSOutlineView,
                   viewFor tableColumn: NSTableColumn?,
                   item: Any) -> NSView?
  {
    guard let columnID = tableColumn?.identifier
    else { return nil }
    let dataSource = fileListDataSource
    let change = dataSource.change(for: item)
    
    switch columnID {
      
      case ColumnID.main:
        guard let cell = outlineView.make(withIdentifier: CellViewID.fileCell,
                                          owner: self) as? FileCellView
        else { return nil }
      
        let path = dataSource.path(for: item) as NSString
      
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
              otherChange: dataSource.unstagedChange(for: item),
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
              change: dataSource.unstagedChange(for: item),
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
    (rowView as? FileRowView)?.outlineView = fileListOutline
  }
}

// MARK: NSSplitViewDelegate
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

// MARK: HunkStaging
extension XTFileViewController: HunkStaging
{
  func patchIndexFile(hunk: GTDiffHunk, stage: Bool)
  {
    guard let selectedChange = self.selectedChange()
    else { return }
    
    do {
      try repo?.patchIndexFile(path: selectedChange.path, hunk: hunk,
                               stage: stage)
    }
    catch let error as XTRepository.Error {
      displayRepositoryAlert(error: error)
    }
    catch let error as NSError {
      displayAlert(error: error)
    }
  }
  
  func stage(hunk: GTDiffHunk)
  {
    patchIndexFile(hunk: hunk, stage: true)
  }
  
  func unstage(hunk: GTDiffHunk)
  {
    patchIndexFile(hunk: hunk, stage: false)
  }
  
  func discard(hunk: GTDiffHunk)
  {
    var encoding = String.Encoding.utf8
  
    guard let controller = view.window?.windowController as? RepositoryController,
          let selectedModel = controller.selectedModel,
          let selectedChange = self.selectedChange(),
          let fileURL = selectedModel.unstagedFileURL(selectedChange.path)
    else {
      NSLog("Setup for discard hunk failed")
      return
    }
    
    do {
      let status = try repo!.status(file: selectedChange.path)
      
      if ((hunk.newStart == 1) && (status.0 == .untracked)) ||
         ((hunk.oldStart == 1) && (status.0 == .deleted)) {
        revert(path: selectedChange.path)
      }
      else {
        let fileText = try String(contentsOf: fileURL, usedEncoding: &encoding)
        guard let result = hunk.applied(to: fileText, reversed: true)
        else {
          throw XTRepository.Error.patchMismatch
        }
        
        try result.write(to: fileURL, atomically: true, encoding: encoding)
      }
    }
    catch let error as XTRepository.Error {
      displayRepositoryAlert(error: error)
    }
    catch let error as NSError {
      displayAlert(error: error)
    }
  }
}
