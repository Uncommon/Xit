import Foundation

class FileListController: NSViewController
{
  struct ColumnID
  {
    static let action = NSUserInterfaceItemIdentifier("action")
    static let file = NSUserInterfaceItemIdentifier("file")
    static let status = NSUserInterfaceItemIdentifier("status")
  }
  
  @IBOutlet weak var listTypeIcon: NSImageView!
  @IBOutlet weak var listTypeLabel: NSTextField!
  @IBOutlet weak var viewSwitch: NSSegmentedControl!
  @IBOutlet weak var toolbarStack: NSStackView!
  @IBOutlet weak var outlineView: NSOutlineView!
  
  var fileListDataSource: FileListDataSourceBase?
  
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
  }
  
  @IBAction func viewSwitched(_ sender: Any)
  {
  }
  
  var clickedChange: FileChange?
  {
    return outlineView.clickedRow == -1
        ? nil
        : nil // file change at index
  }
  
  var selectedChange: FileChange?
  {
    guard let index = outlineView.selectedRowIndexes.first
    else { return nil }
    
    return (fileListDataSource as? FileListDataSource)?.fileChange(at: index)
  }

  func addToolbarButton(name: NSImage.Name, action: Selector)
  {
    let button = NSButton(image: NSImage(named: name)!,
                          target: self, action: action)
  
    button.setFrameSize(NSSize(width: 26, height: 18))
    toolbarStack.insertView(button, at: 0, in: .leading)
  }
}

class CommitFileListController: FileListController
{
  override func awakeFromNib()
  {
    let index = outlineView.column(withIdentifier: ColumnID.action)
    
    outlineView.tableColumns[index].isHidden = true
    
    listTypeIcon.image = NSImage(named: .xtFileTemplate)
    listTypeLabel.stringValue = "Files"
  }
}

class StagedFileListController: FileListController
{
  override func awakeFromNib()
  {
    listTypeIcon.image = NSImage(named: .xtStagingTemplate)
    listTypeLabel.stringValue = "Staged"
    
    addToolbarButton(name: .xtUnstageAllTemplate,
                     action: #selector(unstageAll(_:)))
  }
}

class WorkspaceFileListController: FileListController
{
  override func awakeFromNib()
  {
    listTypeIcon.image = NSImage(named: .xtFolderTemplate)
    listTypeLabel.stringValue = "Workspace"
    
    addToolbarButton(name: .xtStageAllTemplate,
                     action: #selector(stageAll(_:)))
    addToolbarButton(name: .xtRevertTemplate,
                     action: #selector(revert(_:)))
  }
}
