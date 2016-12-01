import Cocoa

class FileListView: ContextMenuOutlineView
{
  @IBOutlet var stagingMenu: NSMenu!
  @IBOutlet var commitMenu: NSMenu!

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
  
  override func updateMenu(forItem item: Any)
  {
    let controller = window?.windowController as! XTWindowController
    
    if controller.selectedModel?.canCommit ?? false {
      menu = stagingMenu
    }
    else {
      menu = commitMenu
    }
  }
}
