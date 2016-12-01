import Cocoa

/// Outline view with dynamic context menus.
class ContextMenuOutlineView: NSOutlineView
{
  public private(set) var contextMenuRow: Int? = nil

  // If you do this in menu(for:) then right-clicking an unselected item
  // doesn't highlight it.
  override func rightMouseDown(with event: NSEvent)
  {
    defer {
      super.rightMouseDown(with: event)
      contextMenuRow = nil
    }
    
    let localPoint = convert(event.locationInWindow, from: nil)
    let clickedRow = row(at: localPoint)
    guard let item = self.item(atRow: clickedRow)
    else { return }
    
    contextMenuRow = clickedRow
    updateMenu(forItem: item)
  }
  
  /// Updates the context menu for the given item.
  /// - parameter item: The item whose row has been right-clicked.
  func updateMenu(forItem item: Any)
  {
  }
}
