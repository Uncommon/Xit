import Foundation

/// Changes for a selected commit in the history
final class CommitSelection: RepositorySelection
{
  unowned var repository: FileChangesRepo
  let commit: Commit
  var shaToSelect: String? { commit.sha }
  var canCommit: Bool { false }
  var fileList: FileListModel { commitFileList }
  
  // Initialization requires a reference to self
  private(set) var commitFileList: CommitFileList!
  
  /// SHA of the parent commit to use for diffs
  var diffParent: GitOID?

  init(repository: FileChangesRepo, commit: Commit)
  {
    self.repository = repository
    self.commit = commit
    
    commitFileList = CommitFileList(selection: self)
  }
}

final class CommitFileList: FileListModel
{
  lazy var changes: [FileChange] =
      self.repository.changes(for: self.commit.oid.sha,
                              parent: self.commit.parentOIDs.first)
  
  weak var commitSelection: CommitSelection!
  var selection: RepositorySelection { commitSelection }
  
  var commit: Commit { commitSelection.commit }
  var diffParent: OID? { commitSelection.diffParent }
  
  init(selection: CommitSelection)
  {
    self.commitSelection = selection
  }
  
  func treeRoot(oldTree: NSTreeNode?) -> NSTreeNode
  {
    guard let tree = commit.tree
    else { return NSTreeNode() }
    let changeList = repository.changes(for: commit.sha, parent: diffParent)
    let loader = TreeLoader(fileChanges: changeList)
    let result = loader.treeRoot(tree: tree, oldTree: oldTree)
    
    postProcess(fileTree: result)
    insertDeletedFiles(root: result, changes: changeList)
    return result
  }
  
  /// Inserts deleted files into a tree based on the given `changes`.
  private func insertDeletedFiles(root: NSTreeNode, changes: [FileChange])
  {
    for change in changes where change.status == .deleted {
      switch findNodeOrParent(root: root, path: change.path) {
        
        case .found(let node):
          if let item = node.representedObject as? FileChange {
            item.status = .deleted
          }
          return
        
        case .parent(let parent):
          guard let parentPath = (parent.representedObject as? FileChange)?
                                 .path.withSuffix("/")
          else { break }
          
          insertDeletionNode(root: parent,
                             subpath: change.path.droppingPrefix(parentPath))
        
        case .notFound:
          insertDeletionNode(root: root, subpath: change.path)
      }
    }
  }
  
  /// Inserts a single deleted item into a tree, adding parent folders as needed
  /// - parameter root: Existing node to insert under
  /// - parameter subpath: Path relative to `root`
  private func insertDeletionNode(root: NSTreeNode, subpath: String)
  {
    guard let rootPath = (root.representedObject as? FileChange)?.path
    else { return }
    let pathKeyExtractor: (NSTreeNode) -> String? = {
          ($0.representedObject as? FileChange)?.path }
    let fullPath = rootPath.appending(pathComponent: subpath)
    let deletionItem = CommitTreeItem(path: fullPath, oid: nil, change: .deleted)
    let deletionNode = NSTreeNode(representedObject: deletionItem)
    
    var loopSubpath = subpath
    var loopName = loopSubpath.firstPathComponent ?? ""
    var loopParent = root
    var subFullPath = loopName
    
    // Insert intervening parents if needed
    while loopSubpath != loopName { // until we have drilled down enough
      let subItem = CommitTreeItem(path: subFullPath)
      let subNode = NSTreeNode(representedObject: subItem)
      
      loopParent.insert(node: subNode, sortedBy: pathKeyExtractor)
      loopSubpath = loopSubpath.deletingFirstPathComponent
      loopName = loopSubpath.firstPathComponent ?? ""
      subFullPath = subFullPath.appending(pathComponent: loopName)
      loopParent = subNode
    }
    
    loopParent.insert(node: deletionNode, sortedBy: pathKeyExtractor)
  }
  
  private enum NodeResult
  {
    case found(NSTreeNode)
    case parent(NSTreeNode) // parent the node should be under
    case notFound
  }
  
  private func findNodeOrParent(root: NSTreeNode, path: String) -> NodeResult
  {
    guard let children = root.children
    else { return .notFound }
    
    for node in children {
      guard let change = node.representedObject as? FileChange
      else { continue }
      
      if change.path == path {
        return .found(node)
      }
      if path.hasPrefix(change.path.withSuffix("/")) {
        let result = findNodeOrParent(root: node, path: path)
        
        switch result {
          case .found, .parent:
            return result
          case .notFound:
            return .parent(node)
        }
      }
    }
    return .notFound
  }
  
  func diffForFile(_ path: String) -> PatchMaker.PatchResult?
  {
    return repository.diffMaker(forFile: path,
                                commitOID: commit.oid,
                                parentOID: diffParent ??
                                           commit.parentOIDs.first)
  }
  
  func blame(for path: String) -> Blame?
  {
    return repository.blame(for: path, from: commit.oid, to: nil)
  }
  
  func dataForFile(_ path: String) -> Data?
  {
    return repository.contentsOfFile(path: path, at: commit)
  }
  
  func fileURL(_ path: String) -> URL?
  {
    return nil
  }
}
