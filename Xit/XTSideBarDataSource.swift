import Cocoa


extension XTSideBarDataSource {
  
  func makeRoots() -> [XTSideBarGroupItem]
  {
    let rootNames =
        ["WORKSPACE", "BRANCHES", "REMOTES", "TAGS", "STASHES", "SUBMODULES"];
    let roots = rootNames.map({ XTSideBarGroupItem(title: $0) })
    
    roots[0].addChild(stagingItem)
    return roots;
  }
  
  func makeTagItems() -> [XTTagItem]
  {
    guard let tags = try? repo.tags()
    else { return [XTTagItem]() }
    
    return tags.map({ XTTagItem(tag: $0)})
  }
  
  func makeStashItems() -> [XTStashItem]
  {
    let stashes = repo.stashes()
    var stashItems = [XTStashItem]()
    
    for (index, stash) in stashes.enumerate() {
      let model = XTStashChanges(repository: repo, stash: stash)
      let message = stash.message ?? "stash \(index)"
    
      stashItems.append(XTStashItem(title: message, model: model))
    }
    return stashItems
  }
  
  func makeSubmoduleItems() -> [XTSubmoduleItem]
  {
    return repo.submodules().map({ XTSubmoduleItem(submodule: $0) })
  }
}

extension XTSideBarDataSource: NSOutlineViewDataSource {
  
  public func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
    if item == nil {
      return roots.count
    }
    return (item as? XTSideBarItem)?.children.count ?? 0
  }
  
  public func outlineView(outlineView: NSOutlineView,
                          isItemExpandable item: AnyObject) -> Bool {
    return (item as? XTSideBarItem)?.expandable ?? false
  }
  
  public func outlineView(outlineView: NSOutlineView,
                          child index: Int,
                          ofItem item: AnyObject?) -> AnyObject {
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
    return item is XTSideBarGroupItem
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
    
    if item is XTSideBarGroupItem {
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
