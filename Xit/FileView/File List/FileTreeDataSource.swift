import Foundation

class FileTreeDataSource: FileListDataSourceBase
{
  fileprivate var root: NSTreeNode
  
  override init(useWorkspaceList: Bool)
  {
    root = NSTreeNode(representedObject: CommitTreeItem(path: "root"))
    
    super.init(useWorkspaceList: useWorkspaceList)
  }
}

extension FileTreeDataSource: FileListDataSource
{
  func reload()
  {
    let currentSelection = repoUIController.selection

    repoUIController.queue.executeOffMainThread {
      [weak self] in
      guard let self = self
      else { return }
      
      objc_sync_enter(self)
      defer { objc_sync_exit(self) }

      guard let selection = currentSelection,
            let fileList = self.useWorkspaceList ?
              (selection as? StagingSelection)?.unstagedFileList :
              selection.fileList
      else { return }
      
      self.delegate?.configure(model: fileList)
      
      let newRoot = fileList.treeRoot(oldTree: self.root)
      
      DispatchQueue.main.async {
        self.root = newRoot
        
        guard let outlineView = self.outlineView
        else { return }
        
        let selectedRow = outlineView.selectedRow
        let selectedChange = self.fileChange(at: selectedRow)
        let expanded = self.expandedPaths()
        
        outlineView.reloadData()
        self.expand(paths: expanded)
        self.reselect(item: selectedChange, oldRow: selectedRow)
      }
    }
  }
  
  private func expandedPaths() -> [String]
  {
    var result = [String]()
    
    for rowIndex in 0..<outlineView.numberOfRows
        where outlineView.isItemExpanded(outlineView.item(atRow: rowIndex)) {
      guard let change = fileChange(at: rowIndex)
      else { continue }
      
      result.append(change.gitPath)
    }
    return result
  }
  
  private func expand(paths: [String])
  {
    var rowIndex = 0
    
    while rowIndex < outlineView.numberOfRows {
      if let change = fileChange(at: rowIndex),
         paths.contains(change.gitPath) {
        outlineView.expandItem(outlineView.item(atRow: rowIndex))
      }
      rowIndex += 1
    }
  }
  
  func reselect(item: FileChange?, oldRow: Int)
  {
    guard let item = item,
          let outlineView = outlineView
    else { return }
    
    if let oldRowItem = fileChange(at: oldRow),
       oldRowItem.gitPath == item.gitPath {
      outlineView.selectRowIndexes(IndexSet(integer: oldRow),
                                   byExtendingSelection: false)
      return
    }
    
    if let newChange = fileChange(at: outlineView.selectedRow),
       item.gitPath != newChange.gitPath {
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
  
  func treeItem(_ item: Any) -> FileChange?
  {
    return (item as? NSTreeNode)?.representedObject as? FileChange
  }
  
  func path(for item: Any) -> String
  {
    return treeItem(item)?.gitPath ?? ""
  }
  
  func change(for item: Any) -> DeltaStatus
  {
    return treeItem(item)?.status ?? .unmodified
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
       change: DeltaStatus = .unmodified)
  {
    self.oid = oid
    super.init(path: path, change: change)
  }
}
