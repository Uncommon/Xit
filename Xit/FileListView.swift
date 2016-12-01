import Cocoa

class FileListView: NSOutlineView
{
  static func columnHighlightColor() -> NSColor
  {
    return NSColor.shadowColor.withAlphaComponent(0.05)
  }

  static func highlightColumn(rect: NSRect)
  {
    var rect = rect
    
    rect.size.width += 2
    NSGraphicsContext.saveGraphicsState()
    FileListView.columnHighlightColor().setFill()
    NSBezierPath.fill(rect)
    NSGraphicsContext.restoreGraphicsState()
  }
  
  func index(of tableColumn: NSTableColumn) -> Int?
  {
    return tableColumns.index(of: tableColumn)
  }
  
  override func drawBackground(inClipRect clipRect: NSRect)
  {
    super.drawBackground(inClipRect: clipRect)
    
    let controller = window?.windowController as! XTWindowController
    guard let tableColumn = highlightedTableColumn,
          let highlightedIndex = index(of: tableColumn),
          controller.selectedModel?.hasUnstaged ?? false
    else { return }
    
    var highlightRect = frameOfCell(atColumn: highlightedIndex, row: 0)
    
    highlightRect.origin.y = clipRect.origin.y
    highlightRect.size.height = clipRect.size.height
    
    FileListView.highlightColumn(rect: highlightRect)
  }
}
