import Cocoa

@objc(XTFileRowView)
class FileRowView: NSTableRowView
{
  weak var outlineView: NSOutlineView!
  
  override func drawBackground(in dirtyRect: NSRect)
  {
    super.drawBackground(in: dirtyRect)
    
    let controller = outlineView.window!.windowController! as! XTWindowController
    
    if (controller.selection is StagedUnstagedSelection) &&
       (interiorBackgroundStyle != .dark) {
      guard let column = outlineView.highlightedTableColumn
      else { return }
      let columnIndex = outlineView.tableColumns.index(of: column)!
      let highlightedView = view(atColumn: columnIndex) as! NSView
      var highlightFrame = highlightedView.frame
      
      highlightFrame.origin.y = 0
      highlightFrame.size.height = frame.size.height
      FileListView.highlightColumn(rect: highlightFrame)
    }
  }
}
