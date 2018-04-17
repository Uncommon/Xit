import Foundation
import Quartz

/// View controller for the file list and detail view.
class FileViewController: NSViewController
{
  /// Column identifiers for the file list
  struct ColumnID
  {
    static let main = ¶"main"
    static let staged = ¶"change"
    static let unstaged = ¶"unstaged"
    static let hidden = ¶"hidden"
  }
  
  /// Table cell view identifiers for the file list
  struct CellViewID
  {
    static let fileCell = ¶"fileCell"
    static let change = ¶"change"
    static let staged = ¶"staged"
    static let unstaged = ¶"unstaged"
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
  
  struct HeaderTab
  {
    static let display = "display"
    static let entry = "entry"
  }
  
  struct FileListTab
  {
    static let commit = "commit"
    static let staging = "staging"
  }
  
  @IBOutlet weak var headerSplitView: NSSplitView!
  @IBOutlet weak var fileSplitView: NSSplitView!
  @IBOutlet weak var fileListSplitView: NSSplitView!
  @IBOutlet weak var fileListTabView: NSTabView!
  @IBOutlet weak var headerTabView: NSTabView!
  @IBOutlet weak var previewTabView: NSTabView!
  @IBOutlet weak var previewPath: NSPathControl!
  @IBOutlet weak var filePreview: QLPreviewView!
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
  
  var repoSelection: RepositorySelection?
  {
    return (view.window?.windowController as? RepositoryController)?.selection
  }
  
  var inStagingView: Bool
  {
    return repoSelection is StagedUnstagedSelection
  }
  
  var selectionCanCommit: Bool
  {
    return repoSelection is StagingSelection
  }
  
  var showingStaged: Bool
  {
    get
    {
      guard let id = fileListTabView.selectedTabViewItem?.identifier as? String
      else { return false }
      
      return id == FileListTab.staging
    }
    set
    {
      fileListTabView.selectTabViewItem(withIdentifier: newValue ?
          FileListTab.staging : FileListTab.commit)
    }
  }
  
  var isCommitting: Bool
  {
    get
    {
      guard let id = headerTabView.selectedTabViewItem?.identifier as? String
      else { return false }
      
      return id == HeaderTab.entry
    }
    set
    {
      headerTabView.selectTabViewItem(at: newValue ? 1 : 0)
    }
  }
  
  let commitListController = CommitFileListController()
  let stagedListController = StagedFileListController()
  let workspaceListController = WorkspaceFileListController()
  
  var activeFileList: NSOutlineView!
  var activeFileListController: FileListController
  {
    return activeFileList.delegate as! FileListController
  }
  var selectedChange: FileChange?
  {
    return activeFileListController.selectedChange
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
                           as? RepositoryController
    else { return }
    
    for listController in [commitListController,
                           stagedListController,
                           workspaceListController] {
      listController.repoController = controller
    }

    observers.addObserver(forName: .XTSelectedModelChanged,
                          object: controller, queue: .main) {
      [weak self] _ in
      self?.selectedModelChanged()
    }
    headerController.repository = repository
    commitEntryController.repo = repository
    
    let commitTabItem = fileListTabView.tabViewItem(at: 0)
    
    commitListController.loadView()
    commitTabItem.viewController = commitListController
    fileListSplitView.addSubview(stagedListController.view)
    fileListSplitView.addSubview(workspaceListController.view)
    activeFileList = commitListController.outlineView
  }
  
  override func loadView()
  {
    super.loadView()
    
    contentController = diffController

    // observe list view selections
    
    observers.addObserver(forName: .XTHeaderResized, object: headerController,
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
        nibName: ◊"XTCommitEntryController", bundle: nil)
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
        // reload the staging lists
        self?.indexTimer = nil
      }
    }
    
    // Ideally, check to see if the selected file has changed
    if selectionCanCommit {
      loadSelectedPreview(force: true)
    }
  }
  
  func reload()
  {
    // reload the visible list
  }
  
  func refreshPreview()
  {
    loadSelectedPreview(force: true)
    //filePreview.refreshPreviewItem()
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
          : NSImage(named: .folder)
      
      return cell
    }
    
    previewPath.setPathComponentCells(cells)
  }
  
  func selectedModelChanged()
  {
    guard let controller = view.window?.windowController
                           as? RepositoryController,
          let newModel = controller.selection
    else { return }
    
    showingStaged = newModel is StagedUnstagedSelection
    isCommitting = newModel is StagingSelection
    headerController.commitSHA = newModel.shaToSelect
    clearPreviews()
    refreshPreview()
  }
  
  func loadSelectedPreview(force: Bool = false)
  {
    guard !contentController.isLoaded || force
    else { return }
    
    guard let repo = repo,
          let index = activeFileList.selectedRowIndexes.first,
          let selectedItem = activeFileList.item(atRow: index),
          let selectedChange = self.selectedChange,
          let controller = view.window?.windowController
                           as? RepositoryController
    else { return }
    
    updatePreviewPath(selectedChange.path,
                      isFolder: activeFileList.isExpandable(selectedItem))
    contentController.load(path: selectedChange.path,
                           selection: controller.selection,
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
}

// MARK: NSSplitViewDelegate
extension FileViewController: NSSplitViewDelegate
{
  public func splitView(_ splitView: NSSplitView,
                        shouldAdjustSizeOfSubview view: NSView) -> Bool
  {
    switch splitView {
      case headerSplitView: // try holding priorities instead
        return view != headerController.view
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
    guard let selectedChange = self.selectedChange
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
          let selection = controller.selection as? StagingSelection,
          let selectedChange = self.selectedChange,
          let fileURL = selection.unstagedFilelist.fileURL(selectedChange.path)
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
