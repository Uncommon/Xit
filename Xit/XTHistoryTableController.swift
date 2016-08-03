import Cocoa

public class XTHistoryTableController: NSViewController {

  var repository: XTRepository!
  {
    didSet
    {
      history = XTCommitHistory(repository: repository)
      if let headSHA = repository.headSHA,
        let headCommit = repository.commit(forSHA: headSHA) {
        history.process(headCommit, afterCommit: nil)
      }
    }
  }
  var history: XTCommitHistory!

}

extension XTHistoryTableController: NSTableViewDelegate {
  
  public func tableView(tableView: NSTableView,
                        viewForTableColumn tableColumn: NSTableColumn?,
                        row: Int) -> NSView?
  {
    guard (row >= 0) && (row < history.entries.count)
    else {
      NSLog("Object value request out of bounds")
      return nil
    }
    guard let tableColumn = tableColumn,
          let result = tableView.makeViewWithIdentifier(
              tableColumn.identifier, owner: self) as? NSTableCellView
    else { return nil }
    
    let entry = history.entries[row]
    
    switch tableColumn.identifier {
      case "commit":
        result.textField?.stringValue = entry.commit.message ?? ""
      case "date":
        result.textField?.objectValue = entry.commit.commitDate
      case "email":
        result.textField?.stringValue = entry.commit.email ?? ""
      default:
        return nil
    }
    return result
  }
 
  public func tableViewSelectionDidChange(notification: NSNotification)
  {
    guard view.window?.firstResponder == view,
          let tableView = notification.object as? NSTableView
    else { return }
    
    let selectedRow = tableView.selectedRow
    
    if (selectedRow >= 0) && (selectedRow < history.entries.count),
       let controller = view.window?.windowController as? XTWindowController,
       let sha = history.entries[selectedRow].commit.SHA {
      controller.selectedModel = XTCommitChanges(repository: repository, sha: sha)
    }
  }
}

extension XTHistoryTableController: NSTableViewDataSource {
  
  public func numberOfRowsInTableView(tableView: NSTableView) -> Int
  {
    return history.entries.count
  }
}
