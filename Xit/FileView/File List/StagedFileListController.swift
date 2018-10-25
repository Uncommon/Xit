import Foundation

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
  
  @IBAction
  override func unstage(_ sender: Any)
  {
    let changes = targetChanges(sender: sender)
    guard !changes.isEmpty
    else { return }
    
    for change in changes {
      _ = try? repoController.repository.unstage(file: change.gitPath)
    }
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
