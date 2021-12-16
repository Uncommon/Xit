import Foundation
import Combine

/// Controller for staged/unstaged file lists. Conceptually (but not actually
/// because of Swift) an abstract class.
class StagingFileListController: FileListController
{
  var indexSink: AnyCancellable?

  /// Actions (used by toolbar buttons) that modify the repository or workspace,
  /// so the buttons should be hidden if a stash is selected.
  var modifyActions: [Selector] = []

  /// True if actions such as stage and revert are available.
  var canModify: Bool { !(repoSelection is StashSelection) }

  override func repoSelectionChanged()
  {
    for action in modifyActions {
      toolbarButton(withAction: action)?.isHidden = !canModify
    }
  }

  func setActionColumnShown(_ shown: Bool)
  {
    outlineView.columnObject(withIdentifier: ColumnID.action)?.isHidden = !shown
  }

  func setWorkspaceControlsShown(_ shown: Bool)
  {
    for case let button as NSButton in toolbarStack.arrangedSubviews {
      switch button.action {
          case #selector(stageAll(_:)),
               #selector(unstageAll(_:)),
               #selector(revert(_:)):
            button.isHidden = !shown
          default:
            break
      }
    }
  }

  override func finishLoad(controller: RepositoryUIController)
  {
    super.finishLoad(controller: controller)

    indexSink = controller.repoController.indexPublisher
      .sinkOnMainQueue {
        [weak self] in
        self?.viewDataSource.reload()
      }
  }

  func addModifyingToolbarButton(image: NSImage,
                                 toolTip: UIString,
                                 target: Any? = self,
                                 action: Selector,
                                 accessibilityID: String? = nil)
  {
    modifyActions.append(action)
    addToolbarButton(image: image, toolTip: toolTip,
                     target: target, action: action,
                     accessibilityID: accessibilityID)
  }

  func reload()
  {
    (outlineView.dataSource as? FileListDataSource)?.reload()
  }
}
