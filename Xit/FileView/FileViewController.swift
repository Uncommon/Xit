import Foundation
import Quartz

/// View controller for the file list and detail view.
class FileViewController: NSViewController
{
  /// Column identifiers for the file list
  enum ColumnID
  {
    static let main = ¶"main"
    static let staged = ¶"change"
    static let unstaged = ¶"unstaged"
    static let hidden = ¶"hidden"
  }
  
  /// Preview tab identifiers
  enum TabID
  {
    static let diff = "diff"
    static let blame = "blame"
    static let text = "text"
    static let preview = "preview"
    
    static let allIDs = [ diff, blame, text, preview ]
  }
  
  enum HeaderTab
  {
    static let display = "display"
    static let entry = "entry"
  }
  
  enum FileListTab
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
  
  var repoController: RepositoryController?
  {
    return view.window?.windowController as? RepositoryController
  }
  
  var repoSelection: RepositorySelection?
  {
    return repoController?.selection
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
  
  let commitListController = CommitFileListController(isWorkspace: false)
  let stagedListController = StagedFileListController(isWorkspace: false)
  let workspaceListController = WorkspaceFileListController(isWorkspace: true)
  let allListControllers: [FileListController]
  
  weak var activeFileList: NSOutlineView!
  {
    didSet { repoController?.updateForFocus() }
  }
  var activeFileListController: FileListController
  {
    return activeFileList.delegate as! FileListController
  }
  var selectedChange: FileChange?
  {
    return activeFileListController.selectedChange
  }
  
  weak var repo: XTRepository?
  
  override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?)
  {
    self.allListControllers = [commitListController,
                               stagedListController,
                               workspaceListController]
    
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
  }
  
  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit
  {
    indexTimer?.invalidate()
  }

  override func awakeFromNib()
  {
    let qlTab = previewTabView.tabViewItem(withIdentifier: TabID.preview)!
    
    qlTab.view = previewController.view
  }
  
  func finishLoad(repository: XTRepository)
  {
    repo = repository

    observers.addObserver(forName: .XTRepositoryIndexChanged,
                          object: repository, queue: .main) {
      [weak self] note in
      self?.indexChanged(note)
    }

    guard let controller = repoController
    else { return }
    
    for listController in allListControllers {
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
    
    let listControllers = [commitListController,
                           stagedListController,
                           workspaceListController]
    
    for controller in listControllers {
      observers.addObserver(forName: NSOutlineView.selectionDidChangeNotification,
                            object: controller.outlineView, queue: .main) {
        [weak self] _ in
        self?.activeFileList = controller.outlineView
        self?.refreshPreview()
      }
    }
    
    observers.addObserver(forName: .xtFirstResponderChanged,
                          object: view.window!, queue: .main) {
      [weak self] _ in
      DispatchQueue.main.async { self?.updatePreviewForActiveList() }
    }
  }
  
  override func loadView()
  {
    super.loadView()
    
    contentController = diffController
    
    commitEntryController = XTCommitEntryController(
        nibName: "XTCommitEntryController", bundle: nil)
    if repo != nil {
      commitEntryController.repo = repo
    }
    
    headerTabView.tabViewItems[1].view = commitEntryController.view
    previewPath.setPathComponentCells([])
    diffController.stagingDelegate = self
  }
  
  func updatePreviewForActiveList()
  {
    if let newActive = self.view.window?.firstResponder as? NSOutlineView,
       newActive != self.activeFileList &&
       self.allListControllers.contains(where: { $0.outlineView === newActive }) {
      self.activeFileList = newActive
      self.refreshPreview()
    }
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
    activeFileList.reloadData()
  }
  
  func refreshPreview()
  {
    DispatchQueue.main.async {
      self.loadSelectedPreview(force: true)
      self.previewController.refreshPreviewItem()
    }
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
          : NSImage(named: NSImage.folderName)
      
      return cell
    }
    
    previewPath.setPathComponentCells(cells)
  }
  
  func selectedModelChanged()
  {
    guard let controller = repoController,
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
          let controller = repoController,
          let repoSelection = controller.selection
    else {
      clearPreviews()
      return
    }
    let staging = repoSelection is StagingSelection
    let staged = activeFileList === stagedListController.outlineView
    let stagingType: StagingType = staging ? (staged ? .index : .workspace)
                                           : .none

    updatePreviewPath(selectedChange.gitPath,
                      isFolder: activeFileList.isExpandable(selectedItem))
    repo.queue.executeOffMainThread {
      self.contentController.load(selection:
          FileSelection(repoSelection: repoSelection,
                        path: selectedChange.gitPath,
                        staging: stagingType))
    }

    let fullPath = repo.repoURL.path.appending(
                      pathComponent: selectedChange.gitPath)
    
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
    DispatchQueue.main.async {
      self.contentControllers.forEach { $0.clear() }
      self.updatePreviewPath("", isFolder: false)
    }
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
  
  func setWrapping(_ wrapping: TextWrapping)
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
    // Supposedly this can be done with holding priorities
    // but that's not working.
    switch splitView {
      case headerSplitView:
        return view != headerTabView
    case fileSplitView:
        return view != fileListTabView
      default:
        return true
    }
  }
}
