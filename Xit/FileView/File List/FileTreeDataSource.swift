import Foundation
import Cocoa

final class FileTreeDataSource: FileListDataSourceBase
{
  fileprivate var root: FileChangeNode

  override init(useWorkspaceList: Bool)
  {
    root = FileChangeNode(value: FileChange(path: "root"))

    super.init(useWorkspaceList: useWorkspaceList)
  }
}

// FileChangeNode is not Sendable, but we're sending it across contexts in very
// limited ways, so it should be safe.
struct TreeNodeContainer: @unchecked Sendable
{
  let node: FileChangeNode
}

extension FileTreeDataSource: FileListDataSource
{
  func reload()
  {
    let currentSelection = repoUIController.selection

    repoUIController.queue.executeAsync {
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
      let (delegate, rootContainer) = await MainActor.run {
        (self.delegate, TreeNodeContainer(node: self.root))
      }
      let root = rootContainer.node

      await delegate?.configure(model: fileList)

      let newRoot = fileList.treeRoot(oldTree: root)
      let container = TreeNodeContainer(node: newRoot)

      await MainActor.run {
        self.root = container.node

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
    
    return (outlineView?.item(atRow: row) as? FileChangeNode)?.value
  }
  
  func treeItem(_ item: Any) -> FileChange?
  {
    return (item as? FileChangeNode)?.value
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
    let children = (item as? FileChangeNode)?.children ?? root.children

    return children.count
  }
  
  func outlineView(_ outlineView: NSOutlineView,
                   isItemExpandable item: Any) -> Bool
  {
    return !((item as? FileChangeNode)?.children.isEmpty ?? true)
  }
  
  func outlineView(_ outlineView: NSOutlineView,
                   child index: Int,
                   ofItem item: Any?) -> Any
  {
    let children = (item as? FileChangeNode)?.children ?? root.children
    guard index < children.count
    else { return FileChangeNode() }
    
    return children[index]
  }
  
  func outlineView(_ outlineView: NSOutlineView,
                   objectValueFor tableColumn: NSTableColumn?,
                   byItem item: Any?) -> Any?
  {
    return (item as? FileChangeNode)?.value
  }
}
