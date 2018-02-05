import Foundation

/// Changes for a selected commit in the history
class CommitChanges: FileChangesModel
{
  unowned var repository: FileChangesRepo
  let commit: XTCommit
  var shaToSelect: String? { return commit.sha }
  var hasUnstaged: Bool { return false }
  var canCommit: Bool { return false }
  
  // Can't currently do changes as as lazy var because it crashes the compiler.
  lazy var changes: [FileChange] =
      self.repository.changes(for: self.commit.oid.sha,
                              parent: self.commit.parentOIDs.first)
  
  /// SHA of the parent commit to use for diffs
  var diffParent: GitOID?

  init(repository: FileChangesRepo, commit: Commit)
  {
    self.repository = repository
    self.commit = commit as! XTCommit
  }
  
  func treeRoot(oldTree: NSTreeNode?) -> NSTreeNode
  {
    guard let tree = commit.tree
    else { return NSTreeNode() }
    let changeList = repository.changes(for: commit.sha, parent: diffParent)
    var changes = [String: DeltaStatus]()
    
    for change in changeList {
      changes[change.path] = change.change
    }
    
    let loader = TreeLoader(changes: changes)
    let result = loader.treeRoot(tree: tree, oldTree: oldTree)
    
    postProcess(fileTree: result)
    insertDeletedFiles(root: result, changes: changes)
    return result
  }
  
  /// Inserts deleted files into a tree based on the given `changes`.
  func insertDeletedFiles(root: NSTreeNode, changes: [String: DeltaStatus])
  {
    for (path, status) in changes where status == .deleted {
      switch findNodeOrParent(root: root, path: path) {
        
        case .found(let node):
          if let item = node.representedObject as? CommitTreeItem {
            item.change = .deleted
          }
          return
        
        case .parent(let parent):
          guard let parentPath = (parent.representedObject as? CommitTreeItem)?
                                 .path
          else { break }
          
          insertDeletionNode(root: parent,
                             subpath: path.removingPrefix(parentPath))
        
        case .notFound:
          insertDeletionNode(root: root, subpath: path)
      }
    }
  }
  
  /// Inserts a single deleted item into a tree, adding parent folders as needed
  func insertDeletionNode(root: NSTreeNode, subpath: String)
  {
    guard let rootPath = (root.representedObject as? CommitTreeItem)?.path
    else { return }
    let path = rootPath.appending(pathComponent: subpath)
    let deletionItem = CommitTreeItem(path: path, oid: nil, change: .deleted)
    let deletionNode = NSTreeNode(representedObject: deletionItem)
    var subsubpath = subpath
    var subName = subsubpath.firstPathComponent ?? ""
    var subParent = root
    let pathKeyExtractor: (NSTreeNode) -> String? = {
          ($0.representedObject as? CommitTreeItem)?.path }
    var subFullPath = subName
    
    // Insert intervening parents if needed
    while subsubpath != subName {
      let subItem = CommitTreeItem(path: subFullPath)
      let subNode = NSTreeNode(representedObject: subItem)
      
      subParent.insert(node: subNode, sortedBy: pathKeyExtractor)
      subsubpath = subsubpath.deletingFirstPathComponent
      subName = subsubpath.firstPathComponent ?? ""
      subFullPath = subFullPath.appending(pathComponent: subName)
      subParent = subNode
    }
    
    subParent.insert(node: deletionNode, sortedBy: pathKeyExtractor)
  }
  
  enum NodeResult
  {
    case found(NSTreeNode)
    case parent(NSTreeNode) // parent the node should be under
    case notFound
  }
  
  func findNodeOrParent(root: NSTreeNode, path: String) -> NodeResult
  {
    guard let children = root.children
    else { return .notFound }
    
    for child in children {
      guard let item = child.representedObject as? CommitTreeItem
      else { continue }
      
      if item.path == path {
        return .found(child)
      }
      if path.hasPrefix(item.path) {
        let result = findNodeOrParent(root: child,
                                      path: path.deletingFirstPathComponent)
        
        switch result {
          case .found, .parent:
            return result
          case .notFound:
            return .parent(child)
        }
      }
    }
    return .notFound
  }
  
  func diffForFile(_ path: String, staged: Bool) -> PatchMaker.PatchResult?
  {
    return repository.diffMaker(forFile: path,
                                commitOID: commit.oid,
                                parentOID: diffParent ??
                                           commit.parentOIDs.first)
  }
  
  func blame(for path: String, staged: Bool) -> Blame?
  {
    return repository.blame(for: path, from: commit.oid, to: nil)
  }
  
  func dataForFile(_ path: String, staged: Bool) -> Data?
  {
    return repository.contentsOfFile(path: path, at: commit)
  }
  
  func unstagedFileURL(_ path: String) -> URL? { return nil }
}
