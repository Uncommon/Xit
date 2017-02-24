import Foundation

class FileTreeDataSource: FileListDataSourceBase
{
  fileprivate var root: NSTreeNode
  
  override init()
  {
    root = NSTreeNode(representedObject: CommitTreeItem(path: "root"))
    
    super.init()
  }
}

extension FileTreeDataSource: FileListDataSource
{
  var hierarchical: Bool { return true }
  
  func reload()
  {
    repository?.executeOffMainThread {
      [weak self] in
      guard let myself = self,
            let newRoot = myself.repoController?.selectedModel?.treeRoot
      else { return }
      
      DispatchQueue.main.async {
        myself.root = newRoot
        if let outlineView = myself.outlineView {
          let selectedRow = outlineView.selectedRow
          let selectedChange = myself.fileChange(at: selectedRow)
          
          outlineView.reloadData()
          myself.reselect(item: selectedChange, oldRow: selectedRow)
        }
      }
    }
  }
  
  func reselect(item: XTFileChange?, oldRow: Int) {
    guard let item = item,
          let outlineView = outlineView
    else { return }
    
    if let oldRowItem = fileChange(at: oldRow),
       oldRowItem.path == item.path {
      outlineView.selectRowIndexes(IndexSet(integer: oldRow),
                                   byExtendingSelection: false)
      return
    }
    
    if let newChange = fileChange(at: outlineView.selectedRow),
       item.path != newChange.path {
      // find the item, expanding as necessary, select it
    }
    if outlineView.selectedRow == -1 {
      outlineView.selectRowIndexes(IndexSet(integer: 0),
                                   byExtendingSelection: false)
    }
  }
  
  func fileChange(at row: Int) -> XTFileChange?
  {
    guard (row >= 0) && (row < outlineView!.numberOfRows)
    else { return nil }
    
    return (outlineView?.item(atRow: row) as? NSTreeNode)?.representedObject
           as? XTFileChange
  }
  
  func treeItem(_ item: Any) -> CommitTreeItem?
  {
    return (item as? NSTreeNode)?.representedObject as? CommitTreeItem
  }
  
  func path(for item: Any) -> String
  {
    return treeItem(item)?.path ?? ""
  }
  
  func change(for item: Any) -> XitChange
  {
    return treeItem(item)!.change
  }
  
  func unstagedChange(for item: Any) -> XitChange
  {
    return treeItem(item)!.unstagedChange
  }
}

extension FileTreeDataSource: NSOutlineViewDataSource
{
  func outlineView(_ outlineView: NSOutlineView,
                            numberOfChildrenOfItem item: Any?) -> Int
  {
    let children = (item as? NSTreeNode)?.children ?? root.children
    
    return children.map { $0.count } ?? 0
  }
  
  func outlineView(_ outlineView: NSOutlineView,
                            isItemExpandable item: Any) -> Bool
  {
    return !((item as? NSTreeNode)?.children?.isEmpty ?? true)
  }
  
  func outlineView(_ outlineView: NSOutlineView,
                            child index: Int,
                            ofItem item: Any?) -> Any
  {
    guard let children = (item as? NSTreeNode)?.children ?? root.children,
          index < children.count
    else { return NSTreeNode() }
    
    return children[index]
  }
  
  func outlineView(_ outlineView: NSOutlineView,
                            objectValueFor tableColumn: NSTableColumn?,
                            byItem item: Any?) -> Any?
  {
    return (item as? NSTreeNode)?.representedObject
  }
}

class CommitTreeItem: XTFileChange
{
}
