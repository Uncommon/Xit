import Foundation

extension XTFileViewController
{
  @IBAction func revert(_: AnyObject)
  {
    guard let selectedRow = fileListOutline.selectedRowIndexes.first,
          let dataSource = fileListDataSource as? XTFileListDataSource,
          let change = dataSource.fileChange(atRow: selectedRow)
    else { return }
    
    do {
      try repo.revert(file: change.path)
    }
    catch let error as NSError {
      let alert = NSAlert(error: error)
      
      alert.beginSheetModal(for: view.window!, completionHandler: nil)
    }
  }
  
  override open func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
  {
    guard let action = menuItem.action
    else { return false }
    
    switch action {
      case #selector(self.revert(_:)):
        guard let selectedRow = fileListOutline.selectedRowIndexes.first,
          let dataSource = fileListDataSource as? XTFileListDataSource,
          let change = dataSource.fileChange(atRow: selectedRow)
          else { return false }
      
          return change.unstagedChange != .unmodified
      default:
        return true
    }
  }
}
