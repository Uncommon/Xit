import Cocoa

protocol XTTableViewDelegate: AnyObject
{
  /// The user has clicked on the selected row.
  func tableViewClickedSelectedRow(_ tableView: NSTableView)
  
  /// Finds the menu for a click in the given cell
  func menu(forRow row: Int, column: Int) -> NSMenu?
}

class HistoryTableView: ContextMenuTableView
{
  override func mouseDown(with event: NSEvent)
  {
    let oldSelection = selectedRowIndexes
    
    super.mouseDown(with: event)
    
    let newSelection = selectedRowIndexes
    
    if oldSelection == newSelection,
       let xtDelegate = delegate as? XTTableViewDelegate {
      xtDelegate.tableViewClickedSelectedRow(self)
    }
  }
  
  override func updateMenu(forRow row: Int, column: Int)
  {
    menu = (delegate as? XTTableViewDelegate)?.menu(forRow: row, column: column)
  }
}
