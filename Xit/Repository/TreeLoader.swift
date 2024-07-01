import Foundation
import Cocoa

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
  public func treeRoot(tree: any Tree, oldTree: FileChangeNode?) -> FileChangeNode
  {
    return treeNode(path: "", tree: tree, oldTree: oldTree)
  }
  
  func treeNode(path: String, tree: some Tree,
                oldTree: FileChangeNode?) -> FileChangeNode
  {
    let result = FileChangeNode(value: FileChange(path: path, oid: tree.id))

    if let oldTree = oldTree,
       oldTree.value.oid == tree.id {
      result.children.append(contentsOf: oldTree.children)
      applyStatus(to: result)
    }
    else {
      for index in 0..<tree.count {
        guard let entry = tree.entry(at: index)
        else { continue }
        let entryPath = path.appending(pathComponent: entry.name)
        
        if entry.type == .tree {
          guard let entryTree = entry.object as? (any Tree)
          else { continue }
          let oldNode = oldTree?.children.first {
            (node) in
            node.value.path.lastPathComponent == entry.name
          }
          
          result.children.append(treeNode(path: entryPath, tree: entryTree,
                                          oldTree: oldNode))
        }
        else {
          let fileStatus = changes[entryPath] ?? .unmodified
          let stagedChange = fileStatus
          let fileItem = FileChange(path: entryPath, oid: entry.id,
                                        change: stagedChange)
          let node = FileChangeNode(value: fileItem)

          result.children.append(node)
        }
      }
    }
    return result
  }
  
  func applyStatus(to node: FileChangeNode)
  {
    node.value.status = changes[node.value.path] ?? .unmodified
    for childNode in node.children {
      applyStatus(to: childNode)
    }
  }
}
