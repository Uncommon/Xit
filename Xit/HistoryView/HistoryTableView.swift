import Cocoa

class HistoryTableView: NSTableView
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
}
