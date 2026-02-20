import Foundation

public protocol FileListModel: AnyObject
{
  var repository: any FileChangesRepo { get }

  /// Changes displayed in the file list
  var changes: [FileChange] { get }

  /// Constructs the file tree
  /// - parameter oldTree: Tree from the previously selected commit, to speed
  /// up loading.
  func treeRoot(oldTree: FileChangeNode?) -> FileChangeNode
  /// Get the diff for the given file.
  /// - parameter path: Repository-relative file path.
  func diffForFile(_ path: String) -> PatchMaker.PatchResult?
  /// Get the contents of the given file.
  /// - parameter path: Repository-relative file path.
  func dataForFile(_ path: String) -> Data?
  /// The URL of the file, if any.
  func fileURL(_ path: String) -> URL?
  /// Generate the blame data for the given file.
  /// - parameter path: Repository-relative file path.
  func blame(for path: String) -> (any Blame)?
  // in lieu of Equatable for now
  func equals(_ other: any FileListModel) -> Bool
}

public extension FileListModel
{
  /// Sets folder change status to match children.
  func postProcess(fileTree tree: FileChangeNode)
  {
    tree.sort()
    updateChanges(tree)
  }

  /// Recursive helper for `postProcess`.
  func updateChanges(_ node: FileChangeNode)
  {
    var change: DeltaStatus?

    for child in node.children {
      let childItem = child.value

      if !child.isLeaf {
        updateChanges(child)
      }

      change = change.map { $0 == childItem.status ? $0 : .mixed }
               ?? childItem.status
    }

    node.value.status = change ?? .unmodified
  }

  func findTreeNode(forPath path: String,
                    parent: FileChangeNode,
                    nodes: inout [String: FileChangeNode]) -> FileChangeNode
  {
    guard !path.isEmpty
    else { return parent }

    if let pathNode = nodes[path] {
      return pathNode
    }
    else {
      let pathNode = FileChangeNode(value: FileChange(path: path))
      let parentPath = (path as NSString).deletingLastPathComponent

      parent.children.append((parentPath.isEmpty) ?
          pathNode :
          findTreeNode(forPath: parentPath, parent: parent, nodes: &nodes))
      nodes[path] = pathNode
      return pathNode
    }
  }

  /// Adds the contents of one tree into another
  func add(_ srcTree: FileChangeNode, to destTree: inout FileChangeNode,
           status: DeltaStatus)
  {
    var srcIndex = 0, destIndex = 0
    var addedNodes = [FileChangeNode]()

    while (srcIndex < srcTree.children.count) &&
          (destIndex < destTree.children.count) {
      let srcItem = srcTree.children[srcIndex].value
      let destItem = destTree.children[destIndex].value

      if destItem.path != srcItem.path {
        let newChange = FileChange(path: srcItem.path, change: status)
        let newNode = FileChangeNode(value: newChange)

        newNode.children.append(contentsOf: srcTree.children[srcIndex].children)
        addedNodes.append(newNode)
      }
      else {
        destIndex += 1
      }
      srcIndex += 1
    }
    destTree.children.append(contentsOf: addedNodes)
    destTree.sort()
  }
}
