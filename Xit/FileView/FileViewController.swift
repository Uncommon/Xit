import Foundation
import Combine
import Quartz

/// View controller for the file list and detail view.
final class FileViewController: NSViewController, RepositoryWindowViewController
{
  typealias Repository = CommitStorage & CommitReferencing & FileContents &
                         FileStaging & FileStatusDetection & RepoConfiguring

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
  @IBOutlet var diffController: FileDiffController!
  @IBOutlet var blameController: BlameViewController!
  @IBOutlet var previewController: PreviewController!
  @IBOutlet var textController: TextPreviewController!
  var commitHeader: CommitHeaderHostingView!
  var commitEntryController: CommitEntryController!

  var resizeRecursing: Bool = false
  var savedSplit: CGFloat = 0
  var options: CurrentValueSubject<FileViewOptions, Never> = .init(.default)

  var contentController: XTFileContentController!
  
  var fileWatcher: FileEventStream?
  var indexTimer: Timer?
  var sinks: [AnyCancellable] = []
  
  var contentControllers: [XTFileContentController]
  { [diffController, blameController, textController, previewController] }
  
  var inStagingView: Bool
  { repoSelection is StagedUnstagedSelection }
  
  /// True if the repository selection supports committing (ie the Staging item)
  var selectionCanCommit: Bool
  { repoSelection is StagingSelection }
  
  /// True when the staged file list is showing (two file lists instead of one)
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
      if newValue {
        let showAction = repoUIController?.selection is StagingSelection
        
        stagedListController.setActionColumnShown(showAction)
        stagedListController.setWorkspaceControlsShown(showAction)
        workspaceListController.setActionColumnShown(showAction)
        workspaceListController.setWorkspaceControlsShown(showAction)
      }
    }
  }
  
  /// True when the commit message entry field is showing
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
  
  var mainFileList: NSOutlineView
  {
    if showingStaged {
      return activeFileList === stagedListController.outlineView ?
          stagedListController.outlineView : workspaceListController.outlineView
    }
    else {
      return commitListController.outlineView
    }
  }
  /// The file list (eg Staged or Workspace) that last had user focus
  weak var activeFileList: NSOutlineView!
  {
    didSet { repoUIController?.updateForFocus() }
  }
  var activeFileListController: FileListController
  { activeFileList.delegate as! FileListController }
  var selectedChange: FileChange?
  { activeFileListController.selectedChange }
  var selectedChanges: [FileChange]
  { activeFileListController.selectedChanges }
  
  weak var repo: (any Repository)?
  {
    didSet
    {
      commitHeader.repository = repo
    }
  }
  
  override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?)
  {
    self.allListControllers = [commitListController,
                               stagedListController,
                               workspaceListController]
    
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

    for controller in allListControllers {
      addChild(controller)
      controller.observeOptions(options.eraseToAnyPublisher())
    }
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

    commitHeader = .init(rootView: CommitHeader(
        commit: nil,
        messageLookup: { _ in "" },
        selectParent: { _ in }))
    commitHeader.selectParent = { [weak self] oid in
      self?.repoUIController?.select(sha: oid.sha)
    }
    
    let scrollView = NSScrollView()

    scrollView.documentView = commitHeader
    scrollView.hasVerticalScroller = true
    headerTabView.tabViewItem(at: 0).view = commitHeader
  }
  
  func finishLoad(repository: any Repository)
  {
    repo = repository
    diffController.repo = repository

    guard let controller = repoUIController
    else { return }

    sinks.append(contentsOf: [
      controller.repoController.indexPublisher
        .sinkOnMainQueue {
          [weak self] in
          self?.indexChanged()
        },
      controller.selectionPublisher
        .sink {
          [weak self] _ in
          self?.selectedModelChanged()
        },
    ])

    commitEntryController.configure(repository: repository,
                                    config: repository.config)
    
    let commitTabItem = fileListTabView.tabViewItem(at: 0)
    
    _ = commitListController.view
    commitTabItem.viewController = commitListController
    fileListSplitView.addSubview(stagedListController.view)
    fileListSplitView.addSubview(workspaceListController.view)
    activeFileList = commitListController.outlineView
    
    // Add the button at this level because the action affects both lists
    stagedListController.addModifyingToolbarButton(
        image: .xtRefresh,
        toolTip: .refresh,
        target: self,
        action: #selector(refreshStaging(_:)),
        accessibilityID: "WorkspaceRefresh")
    
    let listControllers = [commitListController,
                           stagedListController,
                           workspaceListController]
    let center = NotificationCenter.default

    sinks.append(contentsOf: listControllers.map {
      (listController) in
      center.publisher(for: NSOutlineView.selectionDidChangeNotification,
                       object: listController.outlineView)
        .sink {
          [weak self] _ in
          self?.activeFileList = listController.outlineView
          self?.refreshPreview()
        }
    })
    sinks.append(center.publisher(for: .xtFirstResponderChanged,
                                  object: view.window!)
      .sinkOnMainQueue {
        [weak self] _ in
        self?.updatePreviewForActiveList()
      })
  }
  
  override func loadView()
  {
    super.loadView()
    
    contentController = diffController
    
    commitEntryController = CommitEntryController(
        nibName: "CommitEntryController", bundle: nil)
    if let repo = repo {
      commitEntryController.configure(repository: repo, config: repo.config)
    }
    
    headerTabView.tabViewItems[1].view = commitEntryController.view
    previewPath.pathItems = []
    diffController.stagingDelegate = self
  }

  override func viewWillAppear()
  {
    super.viewWillAppear()

    for listController in allListControllers {
      listController.finishLoad(controller: repoUIController!)
    }
  }
  
  func restoreSplit()
  {
    if savedSplit != 0 {
      headerSplitView.setPosition(savedSplit, ofDividerAt: 0)
    }
  }
  
  func saveSplit()
  {
    savedSplit = headerSplitView.arrangedSubviews[0].bounds.height
  }
  
  func updatePreviewForActiveList()
  {
    if let newActive = self.view.window?.firstResponder as? NSOutlineView,
       newActive != self.activeFileList &&
       self.allListControllers.contains(where: { $0.outlineView === newActive }) {
      activeFileList.deselectAll(self)
      activeFileList = newActive
      refreshPreview()
    }
  }
  
  func indexChanged()
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
    let items = components.enumerated().map {
      (index, component) -> NSPathControlItem in
      let workspace = NSWorkspace.shared
      let item = NSPathControlItem()

      item.title = component
      item.image = !isFolder && (index == components.count - 1)
          ? workspace.icon(for: .fromExtension(component.pathExtension))
          : NSImage(named: NSImage.folderName)
      
      return item
    }
    
    previewPath.pathItems = items
  }
  
  func selectedModelChanged()
  {
    guard let controller = repoUIController,
          let newModel = controller.selection
    else { return }
    
    for controller in allListControllers {
      controller.repoSelectionChanged()
    }
    showingStaged = newModel is StagedUnstagedSelection
    isCommitting = newModel is StagingSelection
    if let commit = newModel.oidToSelect.flatMap({ repo?.commit(forOID: $0) }) {
      commitHeader.commit = commit
    }
    clearPreviews()
    refreshPreview()
    DispatchQueue.main.async { // wait for the file lists to refresh
      self.ensureFileSelection()
    }
  }
  
  func ensureFileSelection()
  {
    let outlineViw = mainFileList
    
    if (outlineViw.selectedRow == -1) && (outlineViw.numberOfRows > 0) {
      outlineViw.selectRowIndexes(IndexSet(integer: 0),
                                  byExtendingSelection: false)
    }
  }
  
  func loadSelectedPreview(force: Bool = false)
  {
    guard !contentController.isLoaded || force
    else { return }
    
    let changes = selectedChanges
    guard !changes.isEmpty,
          let repo = repo,
          let index = activeFileList.selectedRowIndexes.first,
          let selectedItem = activeFileList.item(atRow: index),
          let controller = repoUIController,
          let repoSelection = controller.selection
    else {
      clearPreviews()
      return
    }
    let selectedChange = changes.first!
    let staging = repoSelection is StagingSelection
    let staged = activeFileList === stagedListController.outlineView
    let stagingType: StagingType = staging ? (staged ? .index : .workspace)
                                           : .none

    if changes.count == 1 {
      updatePreviewPath(selectedChange.gitPath,
                        isFolder: activeFileList.isExpandable(selectedItem))
    }
    else {
      DispatchQueue.main.async {
        let item = NSPathControlItem()
        
        item.titleString = .multipleSelection
        self.previewPath.pathItems = [item]
      }
    }
    controller.queue.executeOffMainThread {
      let selection = changes.map {
        FileSelection(repoSelection: repoSelection, path: $0.gitPath,
                      staging: stagingType)
      }
      
      self.contentController.load(selection: selection)
    }

    let fullPath = repo.repoURL.path.appending(
                      pathComponent: selectedChange.gitPath)
    
    fileWatcher = inStagingView
        ? FileEventStream(path: fullPath,
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
      self.previewPath.pathItems = []
    }
  }
  
  func clear()
  {
    contentController.clear()
    previewPath.pathItems = []
  }
  
  func revert(path: String)
  {
    let confirmAlert = NSAlert()
    let status = try? repo!.unstagedStatus(for: path)
    let name = (path as NSString).lastPathComponent
    
    confirmAlert.messageString = .confirmRevert(name)
    if status == .untracked {
      confirmAlert.informativeString = .newFileDeleted
    }
    confirmAlert.addButton(withString: .revert)
    confirmAlert.addButton(withString: .cancel)
    confirmAlert.buttons[0].hasDestructiveAction = true
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
    
    alert.beginSheetModal(for: view.window!)
  }
  
  func displayRepositoryAlert(error: RepoError)
  {
    let alert = NSAlert()
    
    alert.messageString = error.message
    alert.beginSheetModal(for: view.window!)
  }

  func revertConfirmed(path: String)
  {
    do {
      try repo?.revert(file: path)
    }
    catch let error as RepoError {
      let alert = NSAlert()
      
      alert.messageString = error.message
      alert.beginSheetModal(for: view.window!)
    }
    catch {
      repoLogger.debug("Unexpected revert error")
    }
  }
}
