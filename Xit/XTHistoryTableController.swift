import Cocoa

public class XTHistoryTableController: NSViewController {

  var repository: XTRepository!
  {
    didSet
    {
      history = XTCommitHistory(repository: repository)

      guard let table = view as? NSTableView
      else { return }
      var spacing = table.intercellSpacing
      
      spacing.height = 0
      table.intercellSpacing = spacing

      let refs = repository.allRefs()
      
      for ref in refs {
        #if DEBUGLOG
        print("-- <\(ref)> --")
        #endif
        guard let sha = repository.shaForRef(ref),
              let commit = repository.commit(forSHA: sha)
        else { continue }
        history.process(commit, afterCommit: nil)
      }
      history.connectCommits()
      table.reloadData()
    }
  }
  
  var history: XTCommitHistory!
  
  override public func viewDidAppear()
  {
    let controller = view.window?.windowController as! XTWindowController
    
    controller.addObserver(self, forKeyPath: "selectedModel",
                           options: .New, context: nil)
  }
  
  /// Selects the row for the given commit SHA.
  func selectRow(sha sha: String?)
  {
    let tableView = view as! NSTableView
    
    guard let sha = sha,
          let row = history.entries.indexOf({ $0.commit.SHA == sha })
    else {
      tableView.deselectAll(self)
      return
    }
    
    tableView.selectRowIndexes(NSIndexSet(index: row),
                               byExtendingSelection: false)
    if view.window?.firstResponder != tableView {
      tableView.scrollRowToVisible(row)
    }
  }
  
  override public func observeValueForKeyPath(
      keyPath: String?, ofObject object: AnyObject?,
      change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>)
  {
    if keyPath == "selectedModel",
       let newModel = change?[NSKeyValueChangeNewKey] as? XTFileChangesModel {
      selectRow(sha: newModel.shaToSelect)
    }
  }
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
    guard let sha = entry.commit.SHA
    else { return nil }
    
    switch tableColumn.identifier {
      case "commit":
        let historyCell = result as! XTHistoryCellView
        
        historyCell.refs = repository.refsAtCommit(sha)
        historyCell.textField?.stringValue = entry.commit.message ?? ""
        historyCell.objectValue = entry
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
