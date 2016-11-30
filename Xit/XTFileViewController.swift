import Foundation

extension XTFileViewController
{
  @IBAction func revert(_: AnyObject)
  {
    guard let selectedRow = fileListOutline.selectedRowIndexes.first,
          let dataSource = fileListDataSource as? XTFileListDataSource,
          let change = dataSource.fileChange(atRow: selectedRow)
    else { return }
    
    let confirmAlert = NSAlert()
    
    confirmAlert.messageText = "Are you sure you want to revert changes to " +
                               "\((change.path as NSString).lastPathComponent)?"
    confirmAlert.addButton(withTitle: "Revert")
    confirmAlert.addButton(withTitle: "Cancel")
    confirmAlert.beginSheetModal(for: view.window!) {
      (response) in
      if response == NSAlertFirstButtonReturn {
        self.revertConfirmed(path: change.path)
      }
    }
  }
  
  func revertConfirmed(path: String)
  {
    do {
      try repo.revert(file: path)
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
