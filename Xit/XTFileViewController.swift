import Foundation

let XTColumnIDStaged = "change"
let XTColumnIDUnstaged = "unstaged"

/// View controller for the file list and detail view.
@objc
class XTFileViewController: NSViewController
{
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
  
  var fileListDataSource: XTFileListDataSource
  {
    return fileListOutline.dataSource as! XTFileListDataSource
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
             XTColumnIDStaged
    }
    set
    {
      let columnID = newValue ? XTColumnIDStaged : XTColumnIDUnstaged
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
      indexObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.XTRepositoryIndexChanged, object: repo, queue: .main) {
        note in
        self.indexChanged(note)
      }
    }
  }
  
  deinit
  {
    indexObserver.map { NotificationCenter.default.removeObserver($0) }
  }

  func windowDidLoad()
  {
    guard let controller = view.window?.windowController
                           as? XTWindowController
    else { return }
    
    fileChangeDS.winController = controller
    fileListDS.winController = controller
    headerController.winController = controller
    modelObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.XTSelectedModelChanged, object: controller, queue: .main) {
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
    
      let unstagedIndex = fileListOutline.column(withIdentifier: XTColumnIDUnstaged)
      let stagedIndex = fileListOutline.column(withIdentifier: XTColumnIDStaged)
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
      case #selector(self.showWhitespaceChanges(_:)),
           #selector(self.ignoreEOLWhitespace(_:)),
           #selector(self.ignoreAllWhitespace(_:)):
        // update the check mark
        return contentController is WhitespaceVariable
      case #selector(self.tabWidth2(_:)),
           #selector(self.tabWidth4(_:)),
           #selector(self.tabWidth6(_:)),
           #selector(self.tabWidth8(_:)):
        // update the check mark
        return contentController is TabWidthVariable
      default:
        return true
    }
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
  // Implemented in XTFileViewController.m
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
