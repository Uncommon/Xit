import Foundation

final class CommitFileListController: FileListController
{
  override func loadView()
  {
    super.loadView()

    let index = outlineView.column(withIdentifier: ColumnID.action)

    outlineView.tableColumns[index].isHidden = true
    outlineView.setAccessibilityIdentifier("commitFiles")

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
