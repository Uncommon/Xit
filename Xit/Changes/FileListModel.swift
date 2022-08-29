import Cocoa
import Foundation

protocol FileListModel: AnyObject
{
  var selection: any RepositorySelection { get }

  /// Changes displayed in the file list
  var changes: [FileChange] { get }

  /// Constructs the file tree
  /// - parameter oldTree: Tree from the previously selected commit, to speed
  /// up loading.
  func treeRoot(oldTree: NSTreeNode?) -> NSTreeNode
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
  func blame(for path: String) -> Blame?
}

extension FileListModel
{
  var repository: any FileChangesRepo { selection.repository }
}

func == (a: any FileListModel, b: any FileListModel) -> Bool
{
  return type(of: a) == type(of: b) &&
         a.selection == b.selection
}

func != (a: any FileListModel, b: any FileListModel) -> Bool
{
  return !(a == b)
}

extension FileListModel
{
  /// Sets folder change status to match children.
  func postProcess(fileTree tree: NSTreeNode)
  {
    let sortDescriptor = NSSortDescriptor(
          key: "path.lastPathComponent",
          ascending: true,
          selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))

    tree.sort(with: [sortDescriptor], recursively: true)
    updateChanges(tree)
  }

  /// Recursive helper for `postProcess`.
  func updateChanges(_ node: NSTreeNode)
  {
    guard let childNodes = node.children
    else { return }

    var change: DeltaStatus?

    for child in childNodes {
      let childItem = child.representedObject as! FileChange

      if !child.isLeaf {
        updateChanges(child)
      }

      change = change.map { $0 == childItem.status ? $0 : .mixed }
               ?? childItem.status
    }

    let nodeItem = node.representedObject as! FileChange

    nodeItem.status = change ?? .unmodified
  }

  func findTreeNode(forPath path: String,
                    parent: NSTreeNode,
                    nodes: inout [String: NSTreeNode]) -> NSTreeNode
  {
    guard !path.isEmpty
    else { return parent }

    if let pathNode = nodes[path] {
      return pathNode
    }
    else {
      let pathNode = NSTreeNode(representedObject: CommitTreeItem(path: path))
      let parentPath = (path as NSString).deletingLastPathComponent

      parent.mutableChildren.add((parentPath.isEmpty) ?
          pathNode :
          findTreeNode(forPath: parentPath, parent: parent, nodes: &nodes))
      nodes[path] = pathNode
      return pathNode
    }
  }

  /// Adds the contents of one tree into another
  func add(_ srcTree: NSTreeNode, to destTree: inout NSTreeNode,
           status: DeltaStatus)
  {
    guard let srcNodes = srcTree.children,
          let destNodes = destTree.children
    else { return }

    var srcIndex = 0, destIndex = 0
    var addedNodes = [NSTreeNode]()

    while (srcIndex < srcNodes.count) && (destIndex < destNodes.count) {
      let srcItem = srcNodes[srcIndex].representedObject! as! FileChange
      let destItem = destNodes[destIndex].representedObject! as! FileChange

      if destItem.path != srcItem.path {
        // NSTreeNode can't be in two trees, so make a new one.
        let newChange = FileChange(path: srcItem.path, change: status)
        let newNode = NSTreeNode(representedObject: newChange)

        newNode.mutableChildren.addObjects(from: srcNodes[srcIndex].children!)
        addedNodes.append(newNode)
      }
      else {
        destIndex += 1
      }
      srcIndex += 1
    }
    destTree.mutableChildren.addObjects(from: addedNodes)
    destTree.mutableChildren.sort(keyPath: "representedObject.path")
  }
}
