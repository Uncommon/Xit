import Foundation

class FileListController: NSViewController
{
  struct ColumnID
  {
    static let action = ¶"action"
    static let file = ¶"file"
    static let status = ¶"status"
    static let hidden = ¶"hidden"
  }
  
  /// Table cell view identifiers for the file list
  struct CellViewID
  {
    static let action = ¶"action"
    static let fileCell = ¶"fileCell"
    static let status = ¶"status"
  }

  @IBOutlet weak var listTypeIcon: NSImageView!
  @IBOutlet weak var listTypeLabel: NSTextField!
  @IBOutlet weak var viewSwitch: NSSegmentedControl!
  @IBOutlet weak var toolbarStack: NSStackView!
  @IBOutlet weak var actionButton: NSPopUpButton!
  @IBOutlet weak var outlineView: NSOutlineView!
  {
    didSet
    {
      fileListDataSource.outlineView = outlineView
      fileTreeDataSource.outlineView = outlineView
      outlineView.dataSource = viewDataSource
      outlineView.delegate = self
      outlineView.outlineTableColumn =
          outlineView.columnObject(withIdentifier: ColumnID.hidden)
    }
  }
  
  var viewDataSource: (FileListDataSourceBase &
                       FileListDataSource &
                       NSOutlineViewDataSource)!
  {
    didSet
    {
      outlineView?.dataSource = viewDataSource
    }
  }
  
  let fileListDataSource: FileChangesDataSource
  let fileTreeDataSource: FileTreeDataSource
  
  var repoController: RepositoryController!
  {
    didSet { didSetRepoController() }
  }
  
  var actionImage: NSImage? { return nil }
  var pressedImage: NSImage? { return nil }
  var actionButtonSelector: Selector? { return nil }
  
  required init(isWorkspace: Bool)
  {
    self.fileListDataSource = FileChangesDataSource(useWorkspaceList: isWorkspace)
    self.fileTreeDataSource = FileTreeDataSource(useWorkspaceList: isWorkspace)

    super.init(nibName: ◊"FileListView", bundle: nil)
    
    viewDataSource = fileListDataSource
  }
  
  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
  
  // didSet isn't overridable so we need a method
  func didSetRepoController()
  {
    fileListDataSource.repoController = repoController
    fileTreeDataSource.repoController = repoController
  }

  @IBAction func stageAll(_ sender: Any)
  {
    try? repoController.repository.stageAllFiles()
  }
  
  @IBAction func unstageAll(_ sender: Any)
  {
    try? repoController.repository.unstageAllFiles()
  }
  
  @IBAction func revert(_ sender: Any)
  {
  }
  
  @IBAction func showIgnored(_ sender: Any)
  {
  }
  
  @IBAction func open(_ sender: Any)
  {
  }
  
  @IBAction func showInFinder(_ sender: Any)
  {
    guard let selectedItem = outlineView.item(atRow: outlineView.selectedRow)
    else { return }
    let path = viewDataSource.path(for: selectedItem)
    let url = repoController.repository.fileURL(path)
    guard FileManager.default.fileExists(atPath: url.path)
    else { return }
    
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
  
  @IBAction func viewSwitched(_ sender: Any)
  {
    // update the outline column
    // change the data source and reload
  }
  
  var clickedChange: FileChange?
  {
    return outlineView.clickedRow == -1
        ? nil
        : viewDataSource.fileChange(at: outlineView.clickedRow)
  }
  
  var selectedChange: FileChange?
  {
    guard let index = outlineView.selectedRowIndexes.first
    else { return nil }
    
    return viewDataSource?.fileChange(at: index)
  }

  func addToolbarButton(imageName: NSImage.Name,
                        toolTip: String,
                        action: Selector)
  {
    let button = NSButton(image: NSImage(named: imageName)!,
                          target: self, action: action)
  
    button.toolTip = toolTip
    button.setFrameSize(NSSize(width: 26, height: 18))
    button.bezelStyle = .smallSquare
    button.isBordered = false
    toolbarStack.insertView(button, at: 0, in: .leading)
    button.widthAnchor.constraint(equalToConstant: 20).isActive = true
  }
}

// MARK: NSOutlineViewDelegate
extension FileListController: NSOutlineViewDelegate
{
  func outlineView(_ outlineView: NSOutlineView,
                   viewFor tableColumn: NSTableColumn?, item: Any) -> NSView?
  {
    guard let columnID = tableColumn?.identifier
    else { return nil }
    let change = viewDataSource.change(for: item)
    
    switch columnID {
      case ColumnID.action:
        guard let cell = outlineView.makeView(withIdentifier: CellViewID.action,
                                              owner: self) as? TableButtonView,
              let button = cell.button as? RolloverButton
        else { break }
      
        button.rolloverImage = actionImage
        button.alternateImage = pressedImage
        button.target = self
        button.action = actionButtonSelector
        return cell
      
      case ColumnID.file:
        guard let cell = outlineView.makeView(withIdentifier: CellViewID.fileCell,
                                              owner: self) as? FileCellView
        else { break }
        let path = viewDataSource.path(for: item)
      
        cell.textField?.stringValue = path.lastPathComponent
        cell.imageView?.image = viewDataSource.outlineView!(outlineView,
                                                            isItemExpandable: item)
            ? NSImage(named: .folder)
            : NSWorkspace.shared.icon(forFileType: path.pathExtension)
        
        cell.textField?.textColor = textColor(for: change,
                                              outlineView: outlineView,
                                              item: item)
        cell.change = change
        return cell

      case ColumnID.status:
        guard let cell = outlineView.makeView(withIdentifier: CellViewID.status,
                                              owner: self)
                         as? NSTableCellView
        else { return nil }
        
        cell.imageView?.image = change.changeImage
        return cell

      default:
          break
    }
    return nil
  }
  
  private func textColor(for change: DeltaStatus, outlineView: NSOutlineView,
                         item: Any)
    -> NSColor
  {
    if change == .deleted {
      return NSColor.disabledControlTextColor
    }
    else if outlineView.isRowSelected(outlineView.row(forItem: item)) {
      return NSColor.selectedTextColor
    }
    else {
      return NSColor.textColor
    }
  }
}

class CommitFileListController: FileListController
{
  override func loadView()
  {
    super.loadView()
    
    let index = outlineView.column(withIdentifier: ColumnID.action)
    
    outlineView.tableColumns[index].isHidden = true
    
    listTypeIcon.image = NSImage(named: .xtFileTemplate)
    listTypeLabel.stringValue = "Files"
  }
}

extension CommitFileListController: NSUserInterfaceValidations
{
  func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool
  {
    let menuItem = item as? NSMenuItem
    
    switch item.action {
      case #selector(open(_:)):
        return outlineView.selectedRow != -1
      case #selector(showInFinder(_:)):
        return outlineView.selectedRow != -1
      default:
        menuItem?.isHidden = true
        return false
    }
  }
}

class StagingFileListController: FileListController
{
  var indexObserver: NSObjectProtocol?
  
  override func didSetRepoController()
  {
    super.didSetRepoController()
    indexObserver = NotificationCenter.default.addObserver(
        forName: .XTRepositoryIndexChanged,
        object: repoController.repository, queue: .main) {
      [weak self] _ in
      self?.viewDataSource.reload()
    }
  }
  
  func postIndexNotification()
  {
    NotificationCenter.default.post(name: .XTRepositoryIndexChanged,
                                    object: repoController.repository)
  }
}

class StagedFileListController: StagingFileListController
{
  override var actionImage: NSImage?
  { return NSImage(named: .xtUnstageButtonHover)! }
  override var pressedImage: NSImage?
  { return NSImage(named: .xtUnstageButtonPressed)! }
  override var actionButtonSelector: Selector?
  { return #selector(self.unstage(_:)) }

  override func loadView()
  {
    super.loadView()
    
    listTypeIcon.image = NSImage(named: .xtStagingTemplate)
    listTypeLabel.stringValue = "Staged"
    
    addToolbarButton(imageName: .xtUnstageAllTemplate,
                     toolTip: "Unstage All",
                     action: #selector(unstageAll(_:)))
  }
  
  @objc
  func unstage(_ sender: NSButton)
  {
    let row = outlineView.row(for: sender)
    guard row != -1,
          let change = viewDataSource.fileChange(at: row)
    else { return }
    
    _ = try? repoController.repository.unstage(file: change.path)
    postIndexNotification()
  }
}

class WorkspaceFileListController: StagingFileListController
{
  override var actionImage: NSImage?
  { return NSImage(named: .xtStageButtonHover)! }
  override var pressedImage: NSImage?
  { return NSImage(named: .xtStageButtonPressed)! }
  override var actionButtonSelector: Selector?
  { return #selector(self.stage(_:)) }

  override func loadView()
  {
    super.loadView()
    
    listTypeIcon.image = NSImage(named: .xtFolderTemplate)
    listTypeLabel.stringValue = "Workspace"
    
    addToolbarButton(imageName: .xtStageAllTemplate,
                     toolTip: "Stage All",
                     action: #selector(stageAll(_:)))
    addToolbarButton(imageName: .xtRevertTemplate,
                     toolTip: "Revert",
                     action: #selector(revert(_:)))
  }
  
  @objc
  func stage(_ sender: NSButton)
  {
    let row = outlineView.row(for: sender)
    guard row != -1,
          let change = viewDataSource.fileChange(at: row)
    else { return }
    
    _ = try? repoController.repository.stage(file: change.path)
    postIndexNotification()
  }
}
