import Foundation
import AppKit
import XitGit

/// Changes for a selected commit in the history
final class CommitSelection: RepositorySelection
{
  unowned var repository: any FileChangesRepo
  let commit: any Commit
  var target: SelectionTarget { .oid(commit.id) }
  var canCommit: Bool { false }
  var fileList: any FileListModel { commitFileList }
  
  // Initialization requires a reference to self
  private(set) var commitFileList: CommitFileList!
  
  /// SHA of the parent commit to use for diffs
  var diffParent: GitOID?

  init(repository: any FileChangesRepo, commit: any Commit)
  {
    self.repository = repository
    self.commit = commit
    
    commitFileList = CommitFileList(repository: repository,
                                    commit: commit,
                                    diffParent: diffParent)
  }
}

final class CommitFileList: FileListModel
{
  unowned var repository: any FileChangesRepo
  lazy var changes: [FileChange] =
      self.repository.changes(for: self.commit.id,
                              parent: self.commit.parentOIDs.first)
  
  let commit: any Commit
  let diffParent: GitOID?

  init(repository: any FileChangesRepo,
       commit: any Commit,
       diffParent: GitOID? = nil)
  {
    self.repository = repository
    self.commit = commit
    self.diffParent = diffParent
  }

  func equals(_ other: FileListModel) -> Bool
  {
    guard let other = other as? CommitFileList
    else { return false }
    return commit.id == other.commit.id && diffParent == other.diffParent
  }
  
  func treeRoot(oldTree: FileChangeNode?) -> FileChangeNode
  {
    treeRoot(oldTree: oldTree, commit: commit)
  }

  /// Generic to unbox `commit`
  func treeRoot(oldTree: FileChangeNode?, commit: some Commit) -> FileChangeNode
  {
    guard let tree = commit.tree
    else { return FileChangeNode() }
    let changeList = repository.changes(for: commit.id, parent: diffParent)
    let loader = TreeLoader(fileChanges: changeList)
    let result = loader.treeRoot(tree: tree, oldTree: oldTree)

    postProcess(fileTree: result)
    insertDeletedFiles(root: result, changes: changeList)
    return result
  }

  /// Inserts deleted files into a tree based on the given `changes`.
  private func insertDeletedFiles(root: FileChangeNode, changes: [FileChange])
  {
    for change in changes where change.status == .deleted {
      switch findNodeOrParent(root: root, path: change.path) {
        
        case .found(let node):
          node.value.status = .deleted
          return
        
        case .parent(let parent):
          let parentPath = parent.value.path.withSuffix("/")

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
  private func insertDeletionNode(root: FileChangeNode, subpath: String)
  {
    let rootPath = root.value.path
    let fullPath = rootPath.appending(pathComponent: subpath)
    let deletionItem = FileChange(path: fullPath, oid: nil, change: .deleted)
    let deletionNode = FileChangeNode(value: deletionItem)

    var loopSubpath = subpath
    var loopName = loopSubpath.firstPathComponent ?? ""
    var loopParent = root
    var subFullPath = loopName
    
    // Insert intervening parents if needed
    while loopSubpath != loopName { // until we have drilled down enough
      let subItem = FileChange(path: subFullPath)
      let subNode = FileChangeNode(value: subItem)

      loopParent.children.insertSorted(subNode)
      loopSubpath = loopSubpath.deletingFirstPathComponent
      loopName = loopSubpath.firstPathComponent ?? ""
      subFullPath = subFullPath.appending(pathComponent: loopName)
      loopParent = subNode
    }
    
    loopParent.children.insertSorted(deletionNode)
  }
  
  private enum NodeResult
  {
    case found(FileChangeNode)
    case parent(FileChangeNode) // parent the node should be under
    case notFound
  }
  
  private func findNodeOrParent(root: FileChangeNode, path: String) -> NodeResult
  {
    for node in root.children {
      if node.value.path == path {
        return .found(node)
      }
      if path.hasPrefix(node.value.path.withSuffix("/")) {
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
                                commitOID: commit.id,
                                parentOID: diffParent ??
                                           commit.parentOIDs.first)
  }
  
  func blame(for path: String) -> (any Blame)?
  {
    return repository.blame(for: path, from: commit.id, to: nil)
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
