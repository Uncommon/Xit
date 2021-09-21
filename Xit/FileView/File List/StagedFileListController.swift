import Foundation

class StagedFileListController: StagingFileListController
{
  override var actionImage: NSImage?
  { .xtUnstageButtonHover }
  override var pressedImage: NSImage?
  { .xtUnstageButtonPressed }
  override var actionButtonSelector: Selector?
  { #selector(self.unstage(_:)) }
  
  override func loadView()
  {
    super.loadView()
    
    outlineView.setAccessibilityIdentifier("stagedFiles")
    listTypeIcon.image = .xtStaged
    listTypeLabel.uiStringValue = .staged
    
    addModifyingToolbarButton(image: .xtUnstageAll,
                              toolTip: .unstageAll,
                              action: #selector(unstageAll(_:)))
  }
  
  @IBAction
  override func unstage(_ sender: Any)
  {
    let changes = targetChanges(sender: sender)
    guard !changes.isEmpty
    else { return }
    
    for change in changes {
      _ = try? repository.unstage(file: change.gitPath)
    }
    repoUIController?.repoController.indexChanged()
  }
  
  @IBAction
  func refresh(_ sender: Any)
  {
    (outlineView.dataSource as? FileListDataSource)?.reload()
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
        menuItem?.isHidden = !canModify
        return selectedChange != nil
      case #selector(unstageAll(_:)):
        menuItem?.isHidden = !canModify
        return outlineView.numberOfRows != 0
      default:
        return super.validateUserInterfaceItem(item)
    }
  }
}
