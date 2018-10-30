import Foundation

class WorkspaceFileListController: StagingFileListController
{
  var showingIgnored = false
  
  override var actionImage: NSImage?
  { return NSImage(named: .xtStageButtonHover)! }
  override var pressedImage: NSImage?
  { return NSImage(named: .xtStageButtonPressed)! }
  override var actionButtonSelector: Selector?
  { return #selector(self.stage(_:)) }
  
  override func loadView()
  {
    super.loadView()
    
    fileListDataSource.delegate = self
    fileTreeDataSource.delegate = self
    
    listTypeIcon.image = NSImage(named: .xtFolderTemplate)
    listTypeLabel.uiStringValue = .workspace
    
    addToolbarButton(imageName: .xtStageAllTemplate,
                     toolTip: .stageAll,
                     action: #selector(stageAll(_:)))
    addToolbarButton(imageName: .xtRevertTemplate,
                     toolTip: .revert,
                     action: #selector(revert(_:)))
  }
  
  @IBAction
  override func stage(_ sender: Any)
  {
    let changes = targetChanges(sender: sender)
    guard !changes.isEmpty
    else { return }
    
    for change in changes {
      _ = try? repoController.repository.stage(file: change.gitPath)
    }
    repoController.postIndexNotification()
  }
  
  @IBAction override func showIgnored(_ sender: Any)
  {
    showingIgnored = !showingIgnored
    viewDataSource.reload()
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
        menuItem?.state = showingIgnored ? .on : .off
        return true
      default:
        return super.validateUserInterfaceItem(item)
    }
  }
}

extension WorkspaceFileListController: FileListDelegate
{
  func configure(model: FileListModel)
  {
    (model as? WorkspaceFileList)?.showingIgnored = showingIgnored
  }
}
