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
    taskQueue?.executeOffMainThread {
      [weak self] in
      guard let myself = self
      else { return }
      
      objc_sync_enter(myself)
      defer { objc_sync_exit(myself) }
      
      guard let model = myself.repoController?.selectedModel
      else { return }
      let newRoot = model.treeRoot(oldTree: myself.root)
      
      DispatchQueue.main.async {
        myself.root = newRoot
        if let outlineView = myself.outlineView {
          let selectedRow = outlineView.selectedRow
          let selectedChange = myself.fileChange(at: selectedRow)
          let expanded = myself.expandedItems()
          
          outlineView.reloadData()
          myself.expandItems(expanded)
          myself.reselect(item: selectedChange, oldRow: selectedRow)
        }
      }
    }
  }
  
  func expandedItems() -> [String]
  {
    var result = [String]()
    
    for rowIndex in 0..<outlineView.numberOfRows
        where outlineView.isItemExpanded(outlineView.item(atRow: rowIndex)) {
      guard let change = fileChange(at: rowIndex)
      else { continue }
      
      result.append(change.path)
    }
    return result
  }
  
  func expandItems(_ expanded: [String])
  {
    for rowIndex in 0..<outlineView.numberOfRows {
      guard let change = fileChange(at: rowIndex)
      else { continue }
      
      if expanded.contains(change.path) {
        outlineView.expandItem(outlineView.item(atRow: rowIndex))
      }
    }
  }
  
  func reselect(item: FileChange?, oldRow: Int)
  {
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
  
  func fileChange(at row: Int) -> FileChange?
  {
    guard (row >= 0) && (row < outlineView!.numberOfRows)
    else { return nil }
    
    return (outlineView?.item(atRow: row) as? NSTreeNode)?.representedObject
           as? FileChange
  }
  
  func treeItem(_ item: Any) -> CommitTreeItem?
  {
    return (item as? NSTreeNode)?.representedObject as? CommitTreeItem
  }
  
  func path(for item: Any) -> String
  {
    return treeItem(item)?.path ?? ""
  }
  
  func change(for item: Any) -> DeltaStatus
  {
    return treeItem(item)?.change ?? .unmodified
  }
  
  func unstagedChange(for item: Any) -> DeltaStatus
  {
    return treeItem(item)?.unstagedChange ?? .unmodified
  }
}

extension FileTreeDataSource: NSOutlineViewDataSource
{
  func outlineView(_ outlineView: NSOutlineView,
                   numberOfChildrenOfItem item: Any?) -> Int
  {
    let children = (item as? NSTreeNode)?.children ?? root.children
    
    return children?.count ?? 0
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

class CommitTreeItem: FileChange
{
  let oid: OID?
  
  init(path: String, oid: OID? = nil,
       change: DeltaStatus = .unmodified,
       unstagedChange: DeltaStatus = .unmodified)
  {
    self.oid = oid
    super.init(path: path, change: change, unstagedChange: unstagedChange)
  }
  
  convenience init(path: String, oid: OID?, status: DeltaStatus, staged: Bool)
  {
    self.init(path: path, oid: oid,
              change: staged ? status : .unmodified,
              unstagedChange: staged ? .unmodified : status)
  }
}
