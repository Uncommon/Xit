import Cocoa


extension XTSideBarDataSource: NSOutlineViewDataSource {
  
  public func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
    outline = outlineView
    
    if item == nil {
      return roots.count
    }
    return (item as? XTSideBarItem)?.children.count ?? 0
  }
  
  public func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
    return (item as? XTSideBarItem)?.expandable ?? false
  }
  
  public func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
    if item == nil {
      return roots[index]
    }
    return (item as! XTSideBarItem).children[index]
  }
}

extension XTSideBarDataSource: NSOutlineViewDelegate {

  public func outlineViewSelectionDidChange(notification: NSNotification)
  {
    guard let item = outline.itemAtRow(outline.selectedRow) as? XTSideBarItem,
          let model = item.model,
          let controller = outline.window?.windowController as? XTWindowController
    else { return }
    
    controller.selectedModel = model
  }


  public func outlineView(outlineView: NSOutlineView,
                          isGroupItem item: AnyObject) -> Bool
  {
    guard let sideBarItem = item as? XTSideBarItem
    else { return false }
    
    return roots.contains(sideBarItem)
  }

  public func outlineView(outlineView: NSOutlineView,
                          shouldSelectItem item: AnyObject) -> Bool
  {
    return (item as? XTSideBarItem)?.selectable ?? false
  }

  public func outlineView(outlineView: NSOutlineView,
                          heightOfRowByItem item: AnyObject) -> CGFloat
  {
    // Using this instead of setting rowSizeStyle because that prevents text
    // from displaying as bold (for the active branch).
   return 20.0
  }

  public func outlineView(outlineView: NSOutlineView,
                          viewForTableColumn tableColumn: NSTableColumn?,
                          item: AnyObject) -> NSView?
  {
    guard let sideBarItem = item as? XTSideBarItem
    else { return nil }
    
    if roots.contains(sideBarItem) {
      guard let headerView = outlineView.makeViewWithIdentifier(
          "HeaderCell", owner: self) as? NSTableCellView
      else { return nil }
      
      headerView.textField?.stringValue = sideBarItem.title
      return headerView
    }
    else {
      guard let dataView = outlineView.makeViewWithIdentifier(
          "DataCell", owner: self) as? XTSideBarTableCellView
      else { return nil }
      
      let textField = dataView.textField!
      
      dataView.item = sideBarItem
      dataView.imageView?.image = sideBarItem.icon
      textField.stringValue = sideBarItem.displayTitle
      textField.editable = sideBarItem.editable
      textField.selectable = sideBarItem.selectable
      if sideBarItem.editable {
        textField.formatter = refFormatter
        textField.target = viewController
        textField.action =
            #selector(XTHistoryViewController.sideBarItemRenamed(_:))
      }
      if sideBarItem.current {
        dataView.button.hidden = false
        textField.font = NSFont.boldSystemFontOfSize(
            textField.font?.pointSize ?? 12)
      }
      else {
        dataView.button.hidden = true
        textField.font = NSFont.systemFontOfSize(
            textField.font?.pointSize ?? 12)
      }
      return dataView
    }
  }
}
