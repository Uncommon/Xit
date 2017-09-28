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
  func load(path: String!, model: FileChangesModel!, staged: Bool)
  /// True if the controller has content loaded.
  var isLoaded: Bool { get }
}

protocol WhitespaceVariable: class
{
  var whitespace: WhitespaceSetting { get set }
}

protocol TabWidthVariable: class
{
  var tabWidth: UInt { get set }
}

protocol ContextVariable: class
{
  var contextLines: UInt { get set }
}

extension XitChange
{
  var isModified: Bool
  {
    switch self {
    case .unmodified, .untracked:
      return false
    default:
      return true
    }
  }
  
  var changeImage: NSImage?
  {
    switch self {
      case .added, .untracked:
        return NSImage(named:NSImage.Name(rawValue: "added"))
      case .copied:
        return NSImage(named:NSImage.Name(rawValue: "copied"))
      case .deleted:
        return NSImage(named:NSImage.Name(rawValue: "deleted"))
      case .modified:
        return NSImage(named:NSImage.Name(rawValue: "modified"))
      case .renamed:
        return NSImage(named:NSImage.Name(rawValue: "renamed"))
      case .mixed:
        return NSImage(named:NSImage.Name(rawValue: "mixed"))
      default:
        return nil
    }
  }
  
  var stageImage: NSImage?
  {
    switch self {
      case .added:
        return NSImage(named:NSImage.Name(rawValue: "add"))
      case .untracked:
        return NSImage(named:NSImage.Name(rawValue: "add"))
      case .deleted:
        return NSImage(named:NSImage.Name(rawValue: "delete"))
      case .modified:
        return NSImage(named:NSImage.Name(rawValue: "modify"))
      case .mixed:
        return NSImage(named:NSImage.Name(rawValue: "mixed"))
      case .conflict:
        return NSImage(named:NSImage.Name(rawValue: "conflict"))
      default:
        return nil
    }
  }
}

/// View controller for the file list and detail view.
class FileViewController: NSViewController
{
  /// Column identifiers for the file list
  struct ColumnID
  {
    static let main = NSUserInterfaceItemIdentifier(rawValue: "main")
    static let staged = NSUserInterfaceItemIdentifier(rawValue: "change")
    static let unstaged = NSUserInterfaceItemIdentifier(rawValue: "unstaged")
    static let hidden = NSUserInterfaceItemIdentifier(rawValue: "hidden")
  }
  
  /// Table cell view identifiers for the file list
  struct CellViewID
  {
    static let fileCell = NSUserInterfaceItemIdentifier(rawValue: "fileCell")
    static let change = NSUserInterfaceItemIdentifier(rawValue: "change")
    static let staged = NSUserInterfaceItemIdentifier(rawValue: "staged")
    static let unstaged = NSUserInterfaceItemIdentifier(rawValue: "unstaged")
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
  
  enum StagingSegment: Int
  {
    case unstageAll
    case stageAll
    case revert
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
  
  var contentController: XTFileContentController!
  let observers = ObserverCollection()
  
  var fileWatcher: FileEventStream?
  weak var lastClickedButton: NSButton?
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
  
  deinit
  {
    indexTimer.map { $0.invalidate() }
  }

  func finishLoad(repository: XTRepository)
  {
    repo = repository

    observers.addObserver(forName: .XTRepositoryIndexChanged,
                          object: repository, queue: .main) {
      [weak self] note in
      self?.indexChanged(note)
    }

    guard let controller = view.window?.windowController
          as? XTWindowController
    else { return }
    
    observers.addObserver(forName: .XTSelectedModelChanged,
                          object: controller, queue: .main) {
      [weak self] _ in
      self?.selectedModelChanged()
    }
    headerController.repository = repository
    commitEntryController.repo = repository
    fileChangeDS.repoController = controller
    fileChangeDS.observe(repository: repository)
    fileChangeDS.taskQueue = repository.queue
    fileTreeDS.repoController = controller
    fileTreeDS.observe(repository: repository)
    fileTreeDS.taskQueue = repository.queue
  }
  
  override func loadView()
  {
    super.loadView()
    
    fileListOutline.highlightedTableColumn =
        fileListOutline.tableColumn(withIdentifier: ColumnID.staged)
    fileListOutline.sizeToFit()
    contentController = diffController
    
    observers.addObserver(
        forName: NSOutlineView.selectionDidChangeNotification,
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
      guard let newHeight =
          (note.userInfo?[CommitHeaderViewController.headerHeightKey]
           as? NSNumber)?.floatValue
      else { return }
      
      self?.headerSplitView.animate(position:CGFloat(newHeight),
                                    ofDividerAtIndex:0)
    }
    
    commitEntryController = XTCommitEntryController(
        nibName: NSNib.Name(rawValue: "XTCommitEntryController"), bundle: nil)
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
        [weak self] (_) in
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
      let workspace = NSWorkspace.shared
      
      cell.title = component
      cell.image = !isFolder && (index == components.count - 1)
          ? workspace.icon(forFileType: (component as NSString).pathExtension)
          : NSImage(named: NSImage.Name.folder)
      
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
      let stagedRect = fileListOutline.rect(ofColumn: stagedIndex)
      let unstagedRect = fileListOutline.rect(ofColumn: unstagedIndex)
      let displayRect = stagedRect.union(unstagedRect)
      
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
  
  func row(for view: NSView?) -> Int?
  {
    guard let view = view
    else { return nil }
    
    if let cellView  = view as? NSTableCellView {
      return fileListOutline.row(for: cellView)
    }
    return row(for: view.superview)
  }

  func clickedChange() -> FileChange?
  {
    return fileListOutline.clickedRow == -1
        ? nil
        : fileListDataSource.fileChange(at: fileListOutline.clickedRow)
  }

  func selectedChange() -> FileChange?
  {
    guard let index = fileListOutline.selectedRowIndexes.first
    else { return nil }
    
    return fileListDataSource.fileChange(at: index)
  }
  
  func selectRow(from button: NSButton)
  {
    guard let row = row(for: button)
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
    guard let row = row(for: button),
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
  
  func stageUnstage(path: String, staging: Bool)
  {
    if staging {
      _ = try? repo?.stage(file: path)
    }
    else {
      _ = try? repo?.unstage(file: path)
    }
    NotificationCenter.default.post(name: .XTRepositoryIndexChanged, object: repo)
  }
  
  /// Handles a click on a staging button.
  func click(button: NSButton, staging: Bool)
  {
    if modelCanCommit && checkDoubleClick(button),
       let path = path(from: button) {
      button.isEnabled = false
      stageUnstage(path: path, staging: staging)
      selectRow(from: button, staged: staging)
    }
    else {
      selectRow(from: button, staged: !staging)
    }
  }
  
  /// Stage/unstage from a context menu command. This differs from `click()`
  /// in that it does not change the selection.
  func stageAction(path: String, staging: Bool)
  {
    stageUnstage(path: path, staging: staging)
    showingStaged = staging
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
      if response == .alertFirstButtonReturn {
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

  func revertConfirmed(path: String)
  {
    do {
      try repo?.revert(file: path)
    }
    catch let error as XTRepository.Error {
      let alert = NSAlert()
      
      alert.messageText = error.message
      alert.beginSheetModal(for: view.window!, completionHandler: nil)
    }
    catch {
      NSLog("Unexpected revert error")
    }
  }
  
  func setWhitespace(_ setting: WhitespaceSetting)
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
  
  func setContext(_ context: UInt)
  {
    guard let contextController = contentController as? ContextVariable
    else { return }
    
    contextController.contextLines = context
  }
  
  func updateStagingSegment()
  {
    let segment = ValidatedSegment(control: stageButtons,
                                   index: StagingSegment.revert.rawValue,
                                   action: #selector(revert(_:)))
    let enabled = validateUserInterfaceItem(segment)
  
    stageButtons.setEnabled(enabled, forSegment: StagingSegment.revert.rawValue)
  }
}

// MARK: NSOutlineViewDelegate
extension FileViewController: NSOutlineViewDelegate
{
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
    
    return change.stageImage
  }

  func updateTableButton(_ button: NSButton,
                         change: XitChange, otherChange: XitChange)
  {
    button.image = modelCanCommit
        ? stagingImage(forChange:change, otherChange:otherChange)
        : change.changeImage
  }

  private func tableButtonView(_ identifier: NSUserInterfaceItemIdentifier,
                               change: XitChange,
                               otherChange: XitChange) -> TableButtonView
  {
    let cellView = fileListOutline.makeView(withIdentifier: identifier,
                                            owner: self)
                   as! TableButtonView
    let button = cellView.button!
    let displayChange = self.displayChange(forChange:change,
                                           otherChange:otherChange)
    
    (button.cell as! NSButtonCell).imageDimsWhenDisabled = false
    button.isEnabled = displayChange != .mixed
    updateTableButton(button, change: change, otherChange: otherChange)
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
        guard let cell = outlineView.makeView(withIdentifier: CellViewID.fileCell,
                                              owner: self) as? FileCellView
        else { return nil }
      
        let path = dataSource.path(for: item) as NSString
      
        cell.imageView?.image = dataSource.outlineView!(outlineView,
                                                       isItemExpandable: item)
                                ? NSImage(named: NSImage.Name.folder)
                                : NSWorkspace.shared
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
              otherChange: dataSource.unstagedChange(for: item))
        }
        else {
          guard let cell = outlineView.makeView(withIdentifier: CellViewID.change,
                                            owner: self)
                           as? NSTableCellView
          else { return nil }
          
          cell.imageView?.image = change.changeImage
          return cell
        }
      
      case ColumnID.unstaged:
        if inStagingView {
          return tableButtonView(
              CellViewID.unstaged,
              change: dataSource.unstagedChange(for: item),
              otherChange: change)
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
  
  func outlineViewSelectionDidChange(_ notification: Notification)
  {
    updateStagingSegment()
  }
}

// MARK: NSSplitViewDelegate
extension FileViewController: NSSplitViewDelegate
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
extension FileViewController: HunkStaging
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
