import Foundation
import Quartz

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
    indexTimer?.invalidate()
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
    
    observers.addObserver(forName: NSOutlineView.selectionDidChangeNotification,
                          object: fileListOutline,
                          queue: .main) {
      [weak self] _ in
      self?.refreshPreview()
    }
    observers.addObserver(forName: .XTHeaderResized,
                          object: headerController,
                          queue: .main) {
      [weak self] note in
      guard let newHeight =
          (note.userInfo?[CommitHeaderViewController.headerHeightKey]
           as? NSNumber)?.floatValue
      else { return }
      
      self?.headerSplitView.animate(position: CGFloat(newHeight),
                                    ofDividerAtIndex: 0)
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
                           as? RepositoryController,
          let model = controller.selectedModel
    else {
      clearPreviews()
      return
    }
    
    updatePreviewPath(selectedChange.path,
                      isFolder: fileListOutline.isExpandable(selectedItem))
    repo.queue.executeOffMainThread {
      self.contentController.load(path: selectedChange.path,
                             model: model,
                             staged: self.showingStaged)
    }
    
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
  
  func stage(path: String) throws
  {
    guard let controller = view.window?.windowController as? RepositoryController
    else { return }
    
    if controller.isAmending {
      //TODO: special case if it's new or deleted
    }
    else {
      try repo?.stage(file: path)
    }
  }
  
  func unstage(path: String) throws
  {
    guard let controller = view.window?.windowController as? RepositoryController
    else { return }
    
    if controller.isAmending {
      //TODO: special case if it's new or deleted
    }
    else {
      try repo?.unstage(file: path)
    }
  }
  
  func stageUnstage(path: String, staging: Bool)
  {
    do {
      if staging {
        try stage(path: path)
      }
      else {
        try unstage(path: path)
      }
      NotificationCenter.default.post(name: .XTRepositoryIndexChanged,
                                      object: repo)
    }
    catch let error as XTRepository.Error {
      if let controller = view.window?.windowController
                          as? RepositoryController {
        controller.showErrorMessage(error: error)
      }
    }
    catch {
      NSLog("Unknown error when staging/unstaging")
    }
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
    updatePreviewPath("", isFolder: false)
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
    (contentController as? WhitespaceVariable)?.whitespace = setting
  }
  
  func setTabWidth(_ tabWidth: UInt)
  {
    (contentController as? TabWidthVariable)?.tabWidth = tabWidth
  }
  
  func setContext(_ context: UInt)
  {
    (contentController as? ContextVariable)?.contextLines = context
  }
  
  func setWrapping(_ wrapping: Wrapping)
  {
    (contentController as? WrappingVariable)?.wrapping = wrapping
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
  func patchIndexFile(hunk: DiffHunk, stage: Bool)
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
  
  func stage(hunk: DiffHunk)
  {
    patchIndexFile(hunk: hunk, stage: true)
  }
  
  func unstage(hunk: DiffHunk)
  {
    patchIndexFile(hunk: hunk, stage: false)
  }
  
  func discard(hunk: DiffHunk)
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
