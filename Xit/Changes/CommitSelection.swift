import Foundation

/// Changes for a selected commit in the history
class CommitSelection: RepositorySelection
{
  unowned var repository: FileChangesRepo
  let commit: Commit
  var shaToSelect: String? { return commit.sha }
  var canCommit: Bool { return false }
  var fileList: FileListModel { return commitFileList }
  
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

class CommitFileList: FileListModel
{
  var stagingType: StagingType { return .none }
  
  lazy var changes: [FileChange] =
      self.repository.changes(for: self.commit.oid.sha,
                              parent: self.commit.parentOIDs.first)
  
  unowned let commitSelection: CommitSelection
  var selection: RepositorySelection { return commitSelection }
  
  var commit: Commit { return commitSelection.commit }
  var diffParent: OID? { return commitSelection.diffParent }
  
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
  func insertDeletedFiles(root: NSTreeNode, changes: [FileChange])
  {
    for change in changes where change.change == .deleted {
      switch findNodeOrParent(root: root, path: change.path) {
        
        case .found(let node):
          if let item = node.representedObject as? FileChange {
            item.change = .deleted
          }
          return
        
        case .parent(let parent):
          guard let parentPath = (parent.representedObject as? FileChange)?
                                 .path
          else { break }
          
          insertDeletionNode(root: parent,
                             subpath: change.path.removingPrefix(parentPath))
        
        case .notFound:
          insertDeletionNode(root: root, subpath: change.path)
      }
    }
  }
  
  /// Inserts a single deleted item into a tree, adding parent folders as needed
  func insertDeletionNode(root: NSTreeNode, subpath: String)
  {
    guard let rootPath = (root.representedObject as? FileChange)?.path
    else { return }
    let path = rootPath.appending(pathComponent: subpath)
    let deletionItem = CommitTreeItem(path: path, oid: nil, change: .deleted)
    let deletionNode = NSTreeNode(representedObject: deletionItem)
    var subsubpath = subpath
    var subName = subsubpath.firstPathComponent ?? ""
    var subParent = root
    let pathKeyExtractor: (NSTreeNode) -> String? = {
          ($0.representedObject as? FileChange)?.path }
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
      guard let item = child.representedObject as? FileChange
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
  
  func fileURL(_ path: String) -> URL? { return nil }
}
