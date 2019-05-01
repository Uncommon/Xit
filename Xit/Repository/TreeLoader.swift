import Foundation

/// Used by RepositorySelection classes for efficiently loading
/// new trees over old ones
public struct TreeLoader
{
  /// Map of paths to file status
  let changes: [String: DeltaStatus]
  
  init(fileChanges: [FileChange])
  {
    var changes = [String: DeltaStatus]()
    
    for fileChange in fileChanges {
      changes[fileChange.path] = fileChange.status
    }
    self.changes = changes
  }
  
  /// Constructs a new tree root, copying identical subtrees from an old tree
  public func treeRoot(tree: Tree, oldTree: NSTreeNode?) -> NSTreeNode
  {
    return treeNode(path: "", tree: tree, oldTree: oldTree)
  }
  
  func treeNode(path: String, tree: Tree, oldTree: NSTreeNode?) -> NSTreeNode
  {
    let result = NSTreeNode(representedObject: CommitTreeItem(path: path,
                                                              oid: tree.oid))
    
    if let oldTree = oldTree,
       let oldItem = oldTree.representedObject as? CommitTreeItem,
      oldItem.oid?.equals(tree.oid) ?? false {
      oldTree.children.map { result.mutableChildren.addObjects(from: $0) }
      applyStatus(to: result)
    }
    else {
      for index in 0..<tree.count {
        guard let entry = tree.entry(at: index)
        else { continue }
        let entryPath = path.appending(pathComponent: entry.name)
        
        if entry.type == .tree {
          guard let entryTree = entry.object as? Tree
          else { continue }
          let oldNode = oldTree?.children?.first {
            (node) in
            (node.representedObject as? FileChange)?
                .path.lastPathComponent == entry.name
          }
          
          result.mutableChildren.add(treeNode(path: entryPath, tree: entryTree,
                                              oldTree: oldNode))
        }
        else {
          let fileStatus = changes[entryPath] ?? .unmodified
          let stagedChange = fileStatus
          let fileItem = CommitTreeItem(path: entryPath, oid: entry.oid,
                                        change: stagedChange)
          let node = NSTreeNode(representedObject: fileItem)
          
          result.mutableChildren.add(node)
        }
      }
    }
    return result
  }
  
  func applyStatus(to node: NSTreeNode)
  {
    guard let item = node.representedObject as? FileChange
    else { return }
    
    item.status = changes[item.path] ?? .unmodified
    if let children = node.children {
      for childNode in children {
        applyStatus(to: childNode)
      }
    }
  }
}
