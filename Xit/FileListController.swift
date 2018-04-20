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
    didSet
    {
      fileListDataSource.repoController = repoController
      fileTreeDataSource.repoController = repoController
    }
  }
  
  required init()
  {
    self.fileListDataSource = FileChangesDataSource()
    self.fileTreeDataSource = FileTreeDataSource()
    
    super.init(nibName: ◊"FileListView", bundle: nil)
    
    viewDataSource = fileListDataSource
  }
  
  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
  
  @IBAction func stageAll(_ sender: Any)
  {
  }
  
  @IBAction func unstageAll(_ sender: Any)
  {
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
    button.widthAnchor.constraint(equalToConstant: 29).isActive = true
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
                                              owner: self) as? NSTableCellView
        else { break }
      
        cell.imageView?.image = NSImage(named: .xtActionButtonEmpty)
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

class StagedFileListController: FileListController
{
  override func loadView()
  {
    super.loadView()
    
    listTypeIcon.image = NSImage(named: .xtStagingTemplate)
    listTypeLabel.stringValue = "Staged"
    
    addToolbarButton(imageName: .xtUnstageAllTemplate,
                     toolTip: "Unstage All",
                     action: #selector(unstageAll(_:)))
  }
}

class WorkspaceFileListController: FileListController
{
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
}
