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
  
  struct ViewSegment
  {
    static let list: Int32 = 0
    static let outline: Int32 = 1
  }

  @IBOutlet weak var listTypeIcon: NSImageView!
  @IBOutlet weak var listTypeLabel: NSTextField!
  @IBOutlet weak var viewSwitch: NSSegmentedControl!
  @IBOutlet weak var toolbarStack: NSStackView!
  @IBOutlet weak var actionButton: NSPopUpButton!
  @IBOutlet weak var outlineView: FileListView!
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
  
  override func loadView()
  {
    super.loadView()
    updateButtons()
  }
  
  // didSet isn't overridable so we need a method
  func didSetRepoController()
  {
    fileListDataSource.repoController = repoController
    fileTreeDataSource.repoController = repoController
  }

  // These are implemented in subclasses, and are here for convenience
  // in hooking up xib items
  @IBAction func stage(_ sender: Any) {}
  @IBAction func unstage(_ sender: Any) {}
  
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
    guard let change = targetChange(sender: sender)
    else { return }
    
    try? repoController.repository.revert(file: change.path)
  }
  
  @IBAction func showIgnored(_ sender: Any)
  {
  }
  
  @IBAction func open(_ sender: Any)
  {
    guard let change = targetChange(sender: sender)
    else { return }
    let url = repoController.repository.fileURL(change.path)
    
    NSWorkspace.shared.open(url)
  }
  
  @IBAction func showInFinder(_ sender: Any)
  {
    guard let change = targetChange(sender: sender)
    else { return }
    let url = repoController.repository.fileURL(change.path)
    guard FileManager.default.fileExists(atPath: url.path)
    else { return }
    
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
  
  @IBAction func viewSwitched(_ sender: Any)
  {
    let listView = viewSwitch.intValue == ViewSegment.list
    
    viewDataSource = listView ? fileListDataSource : fileTreeDataSource
    viewDataSource.reload()
    outlineView.outlineTableColumn = outlineView.columnObject(withIdentifier:
        listView ? ColumnID.hidden : ColumnID.file)
    outlineView.reloadData()
  }
  
  var clickedChange: FileChange?
  {
    return outlineView.contextMenuRow.flatMap { viewDataSource.fileChange(at: $0) }
  }
  
  var selectedChange: FileChange?
  {
    guard let index = outlineView.selectedRowIndexes.first
    else { return nil }
    
    return viewDataSource?.fileChange(at: index)
  }
  
  func buttonChange(sender: Any) -> FileChange?
  {
    guard let button = sender as? NSButton
    else { return nil }
    let row = outlineView.row(for: button)
    
    return viewDataSource.fileChange(at: row)
  }
  
  func targetChange(sender: Any) -> FileChange?
  {
    return buttonChange(sender: sender) ?? clickedChange ?? selectedChange
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
  
  func updateButtons()
  {
    for button in toolbarStack.subviews.compactMap({ $0 as? NSButton })
        where button != actionButton {
      button.isEnabled = validateUserInterfaceItem(button)
    }
  }
}

extension FileListController: NSUserInterfaceValidations
{
  func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool
  {
    switch item.action {
      case #selector(showInFinder(_:)),
           #selector(open(_:)):
        return selectedChange != nil
      default:
        return false
    }
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
        guard change != .unmodified,
              let cell = outlineView.makeView(withIdentifier: CellViewID.action,
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
  
  func outlineViewSelectionDidChange(_ notification: Notification)
  {
    updateButtons()
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

// NSUserInterfaceValidations
extension CommitFileListController
{
  override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem)
    -> Bool
  {
    let menuItem = item as? NSMenuItem
    
    switch item.action {
      case #selector(open(_:)),
           #selector(showInFinder(_:)):
        return super.validateUserInterfaceItem(item)
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
  override func unstage(_ sender: Any)
  {
    guard let change = targetChange(sender: sender)
    else { return }

    _ = try? repoController.repository.unstage(file: change.path)
    repoController.postIndexNotification()
  }
}

// NSUserInterfaceValidations
extension StagedFileListController
{
  override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem)
    -> Bool
  {
    let menuItem = item as? NSMenuItem
    
    switch item.action {
      case #selector(stageAll(_:)),
           #selector(revert(_:)),
           #selector(showIgnored(_:)):
        menuItem?.isHidden = true
        return false
      case #selector(unstage(_:)):
        return selectedChange != nil
      case #selector(unstageAll(_:)):
        return outlineView.numberOfRows != 0
      default:
        return super.validateUserInterfaceItem(item)
    }
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
  override func stage(_ sender: Any)
  {
    guard let change = targetChange(sender: sender)
    else { return }

    _ = try? repoController.repository.stage(file: change.path)
    repoController.postIndexNotification()
  }
}

// NSUserInterfaceValidations
extension WorkspaceFileListController
{
  override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem)
    -> Bool
  {
    let menuItem = item as? NSMenuItem
    
    switch item.action {
      case #selector(unstageAll(_:)):
        menuItem?.isHidden = true
        return false
      case #selector(stage(_:)),
           #selector(revert(_:)):
        return selectedChange != nil
      case #selector(stageAll(_:)):
        return outlineView.numberOfRows != 0
      case #selector(showIgnored(_:)):
        // update the check mark
        return true
      default:
        return super.validateUserInterfaceItem(item)
    }
  }
}
