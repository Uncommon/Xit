import Foundation

final class CommitFileListController: FileListController
{
  override func loadView()
  {
    super.loadView()

    view.setAccessibilityElement(true)
    view.setAccessibilityIdentifier(.FileList.Commit.group)
    view.setAccessibilityRole(.group)

    let index = outlineView.column(withIdentifier: ColumnID.action)

    outlineView.tableColumns[index].isHidden = true
    outlineView.setAccessibilityIdentifier(.FileList.Commit.list)

    listTypeIcon.image = .xtFile
    listTypeLabel.uiStringValue = .files
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
