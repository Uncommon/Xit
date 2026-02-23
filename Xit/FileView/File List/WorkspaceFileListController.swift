import Foundation
import Cocoa
import XitGit

final class WorkspaceFileListController: StagingFileListController
{
  var showingIgnored = false
  
  override var actionImage: NSImage?
  { .xtStageButtonHover }
  override var pressedImage: NSImage?
  { .xtStageButtonPressed }
  override var actionButtonSelector: Selector?
  { #selector(self.stage(_:)) }
  
  override func loadView()
  {
    super.loadView()

    view.setAccessibilityElement(true)
    view.setAccessibilityIdentifier(.FileList.Workspace.group)
    view.setAccessibilityRole(.group)
    outlineView.setAccessibilityIdentifier(.FileList.Workspace.list)

    fileListDataSource.delegate = self
    fileTreeDataSource.delegate = self
    
    listTypeIcon.image = NSImage(systemSymbolName: "folder",
                                 accessibilityDescription: nil)
    listTypeLabel.uiStringValue = .workspace
    
    addModifyingToolbarButton(image: .xtStageAll,
                              toolTip: .stageAll,
                              action: #selector(stageAll(_:)))
    addModifyingToolbarButton(image: .xtUndo,
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
      _ = try? repository.stage(change: change)
    }
    repoUIController?.repoController.indexChanged()
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
        menuItem?.isHidden = !canModify
        return selectedChange != nil
      case #selector(stageAll(_:)):
        menuItem?.isHidden = !canModify
        return outlineView.numberOfRows != 0
      case #selector(showIgnored(_:)):
        menuItem?.isHidden = !canModify
        menuItem?.state = showingIgnored ? .on : .off
        return true
      default:
        return super.validateUserInterfaceItem(item)
    }
  }
}

extension WorkspaceFileListController: FileListDelegate
{
  func configure(model: any FileListModel)
  {
    (model as? WorkspaceFileList)?.showingIgnored = showingIgnored
  }
}
