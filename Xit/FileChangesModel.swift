import Cocoa


typealias FileChangesRepo =
    CommitReferencing & FileDiffing & FileContents & FileStaging

/// Protocol for a commit or commit-like object,
/// with metadata, files, and diffs.
protocol FileChangesModel
{
  var repository: FileChangesRepo { get set }
  /// SHA for commit to be selected in the history list
  var shaToSelect: String? { get }
  /// Changes displayed in the file list
  var changes: [FileChange] { get }
  /// Are there staged and unstaged changes?
  var hasUnstaged: Bool { get }
  /// Is this used to stage and commit files?
  var canCommit: Bool { get }
  
  /// Constructs the file tree
  /// - parameter oldTree: Tree from the previously selected commit, to speed
  /// up loading.
  func treeRoot(oldTree: NSTreeNode?) -> NSTreeNode
  /// Get the diff for the given file.
  /// - parameter path: Repository-relative file path.
  /// - parameter staged: Whether to show the staged or unstaged diff. Ignored
  /// for models that don't have unstaged files.
  func diffForFile(_ path: String, staged: Bool) -> PatchMaker.PatchResult?
  /// Get the contents of the given file.
  /// - parameter path: Repository-relative file path.
  /// - parameter staged: Whether to show the staged or unstaged diff. Ignored
  /// for models that don't have unstaged files.
  func dataForFile(_ path: String, staged: Bool) -> Data?
  /// The URL of the unstaged file, if any.
  func unstagedFileURL(_ path: String) -> URL?
  /// Generate the blame data for the given file.
  /// - parameter path: Repository-relative file path.
  /// - parameter staged: Whether to show the staged or unstaged file. Ignored
  /// for models that don't have unstaged files.
  func blame(for path: String, staged: Bool) -> Blame?
}

func == (a: FileChangesModel, b: FileChangesModel) -> Bool
{
  return type(of: a) == type(of: b) &&
         a.shaToSelect == b.shaToSelect
}

func != (a: FileChangesModel, b: FileChangesModel) -> Bool
{
  return !(a == b)
}


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
    return treeRoot(oldTree: oldTree, staged: true)
  }
  
  func treeRoot(oldTree: NSTreeNode?, staged: Bool) -> NSTreeNode
  {
    guard let tree = commit.tree
    else { return NSTreeNode() }
    let changeList = repository.changes(for: commit.sha, parent: diffParent)
    var changes = [String: DeltaStatus]()
    
    for change in changeList {
      changes[change.path] = change.change
    }
    
    let loader = TreeLoader(changes: changes, staged: staged)
    let result = loader.treeRoot(tree: tree, oldTree: oldTree)
    
    postProcess(fileTree: result)
    insertDeletedFiles(root: result, changes: changes, staged: staged)
    return result
  }
  
  /// Inserts deleted files into a tree based on the given `changes`.
  func insertDeletedFiles(root: NSTreeNode, changes: [String: DeltaStatus],
                          staged: Bool)
  {
    for (path, status) in changes where status == .deleted {
      switch findNodeOrParent(root: root, path: path) {
        
        case .found(let node):
          if let item = node.representedObject as? CommitTreeItem {
            if staged {
              item.change = .deleted
            }
            else {
              item.unstagedChange = .deleted
            }
          }
          return
        
        case .parent(let parent):
          guard let parentPath = (parent.representedObject as? CommitTreeItem)?
                                 .path
          else { break }
          
          insertDeletionNode(root: parent,
                             subpath: path.removingPrefix(parentPath),
                             staged: staged)
        
        case .notFound:
          insertDeletionNode(root: root, subpath: path, staged: staged)
      }
    }
  }
  
  /// Inserts a single deleted item into a tree, adding parent folders as needed
  func insertDeletionNode(root: NSTreeNode, subpath: String, staged: Bool)
  {
    guard let rootPath = (root.representedObject as? CommitTreeItem)?.path
    else { return }
    let path = rootPath.appending(pathComponent: subpath)
    let deletionItem = CommitTreeItem(path: path, oid: nil,
                                      status: .deleted, staged: staged)
    let deletionNode = NSTreeNode(representedObject: deletionItem)
    var subsubpath = subpath
    var subName = subsubpath.firstPathComponent ?? ""
    var subParent = root
    let pathKeyExtractor: (NSTreeNode) -> String? = {
          ($0.representedObject as? CommitTreeItem)?.path }
    
    // Insert intervening parents if needed
    while subsubpath != subName {
      let subItem = CommitTreeItem(path: "")
      let subNode = NSTreeNode(representedObject: subItem)
      
      subParent.insert(node: subNode, sortedBy: pathKeyExtractor)
      subsubpath = subsubpath.deletingFirstPathComponent
      subName = subsubpath.firstPathComponent ?? ""
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


/// Changes for a selected stash, merging workspace, index, and untracked
class StashChanges: FileChangesModel
{
  unowned var repository: FileChangesRepo
  var stash: Stash
  var hasUnstaged: Bool { return true }
  var canCommit: Bool { return false }
  var shaToSelect: String? { return stash.mainCommit?.parentSHAs[0] }
  var changes: [FileChange] { return stash.changes() }
  
  init(repository: FileChangesRepo & Stashing, index: UInt)
  {
    self.repository = repository
    self.stash = repository.stash(index: index, message: nil)
  }
  
  init(repository: FileChangesRepo, stash: XTStash)
  {
    self.repository = repository
    self.stash = stash
  }
  
  func treeRoot(oldTree: NSTreeNode?) -> NSTreeNode
  {
    guard let mainModel = stash.mainCommit.map({
        CommitChanges(repository: repository, commit: $0) })
    else { return NSTreeNode() }
    var mainRoot = mainModel.treeRoot(oldTree: oldTree, staged: false)
    
    if let indexCommit = stash.indexCommit {
      let indexModel = CommitChanges(repository: repository,
                                     commit: indexCommit)
      let indexRoot = indexModel.treeRoot(oldTree: oldTree)
      
      combineTrees(unstagedTree: &mainRoot,
                   stagedTree: indexRoot)
    }
    if let untrackedCommit = stash.untrackedCommit {
      let untrackedModel = CommitChanges(repository: repository,
                                         commit: untrackedCommit)
      let untrackedRoot = untrackedModel.treeRoot(oldTree: oldTree)
    
      add(untrackedRoot, to: &mainRoot)
    }
    return mainRoot
  }
  
  func diffForFile(_ path: String, staged: Bool) -> PatchMaker.PatchResult?
  {
    if staged {
      return stash.stagedDiffForFile(path)
    }
    else {
      return stash.unstagedDiffForFile(path)
    }
  }
  
  func commit(for path: String, staged: Bool) -> Commit?
  {
    if staged {
      return stash.indexCommit
    }
    else {
      if let untrackedCommit = stash.untrackedCommit as? XTCommit,
         untrackedCommit.tree?.entry(path: path) != nil {
        return untrackedCommit
      }
      else {
        return stash.mainCommit
      }
    }
  }
  
  func blame(for path: String, staged: Bool) -> Blame?
  {
    guard let startCommit = commit(for: path, staged: staged)
    else { return nil }
    
    return repository.blame(for: path, from: startCommit.oid, to: nil)
  }
  
  func dataForFile(_ path: String, staged: Bool) -> Data?
  {
    if staged {
      guard let indexCommit = stash.indexCommit
      else { return nil }
      
      return repository.contentsOfFile(path: path, at: indexCommit)
    }
    else {
      if let untrackedCommit = stash.untrackedCommit,
         let untrackedData = repository.contentsOfFile(
              path: path, at: untrackedCommit) {
        return untrackedData
      }
      
      guard let commit = stash.mainCommit
      else { return nil }
      
      return repository.contentsOfFile(path: path, at: commit)
    }
  }

  // Unstaged files are stored in commits, so there is no URL.
  func unstagedFileURL(_ path: String) -> URL? { return nil }
}

func == (a: StashChanges, b: StashChanges) -> Bool
{
  return a.stash.mainCommit?.oid.sha == b.stash.mainCommit?.oid.sha
}


/// Staged and unstaged workspace changes
class StagingChanges: FileChangesModel
{
  unowned var repository: FileChangesRepo
  var shaToSelect: String? { return XTStagingSHA }
  var hasUnstaged: Bool { return true }
  var canCommit: Bool { return true }
  var changes: [FileChange]
  { return repository.changes(for: XTStagingSHA, parent: nil) }
  
  init(repository: FileChangesRepo)
  {
    self.repository = repository
  }
  
  func treeRoot(oldTree: NSTreeNode?) -> NSTreeNode
  {
    let builder = WorkspaceTreeBuilder(changes: repository.workspaceStatus)
    let root = builder.build(repository.repoURL)
    
    postProcess(fileTree: root)
    return root
  }
  
  func diffForFile(_ path: String, staged: Bool) -> PatchMaker.PatchResult?
  {
    if staged {
      return repository.stagedDiff(file: path)
    }
    else {
      return repository.unstagedDiff(file: path)
    }
  }
  
  func blame(for path: String, staged: Bool) -> Blame?
  {
    if staged {
      guard let data = repository.contentsOfStagedFile(path: path)
      else { return nil }
      
      return repository.blame(for: path, data: data, to: nil)
    }
    else {
      return repository.blame(for: path, from: nil, to: nil)
    }
  }
  
  func dataForFile(_ path: String, staged: Bool) -> Data?
  {
    if staged {
      return repository.contentsOfStagedFile(path: path)
    }
    else {
      let url = repository.fileURL(path)
      
      return try? Data(contentsOf: url)
    }
  }
  
  func unstagedFileURL(_ path: String) -> URL?
  {
    return repository.fileURL(path)
  }
}


extension FileChangesModel
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
    
    var change: DeltaStatus?, unstagedChange: DeltaStatus?
    
    for child in childNodes {
      let childItem = child.representedObject as! CommitTreeItem
      
      if !child.isLeaf {
        updateChanges(child)
      }
      
      if change == nil {
        change = childItem.change
      }
      else if change! != childItem.change {
        change = DeltaStatus.mixed
      }
      
      if unstagedChange == nil {
        unstagedChange = childItem.unstagedChange
      }
      else if unstagedChange! != childItem.unstagedChange {
        unstagedChange = DeltaStatus.mixed
      }
    }
    
    let nodeItem = node.representedObject as! CommitTreeItem
    
    nodeItem.change = change ?? .unmodified
    nodeItem.unstagedChange = unstagedChange ?? .unmodified
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

  /// Merges a tree of unstaged changes into a tree of staged changes.
  func combineTrees(unstagedTree: inout NSTreeNode,
                    stagedTree: NSTreeNode)
  {
    // Not sure if these should be expected
    guard let unstagedNodes = unstagedTree.children
    else {
      print("""
            combineTrees: no unstaged children at
            \((unstagedTree.representedObject! as? FileChange)?.path ?? "?"))
            """)
      return
    }
    guard let stagedNodes = stagedTree.children
    else {
      print("""
            combineTrees: no staged children at
            \((stagedTree.representedObject! as? FileChange)?.path ?? "?"))
            """)
      return
    }
    
    // Do a parallel iteration to more efficiently find additions & deletions.
    var unstagedIndex = 0, stagedIndex = 0
    var deletedItems = [FileChange]()
    
    while (unstagedIndex < unstagedNodes.count) &&
          (stagedIndex < stagedNodes.count) {
      var unstagedNode = unstagedNodes[unstagedIndex]
      let unstagedItem = unstagedNode.representedObject! as! FileChange
      let stagedNode = stagedNodes[stagedIndex]
      let stagedItem = stagedNode.representedObject! as! FileChange
      
      switch (unstagedItem.path as NSString).compare(stagedItem.path) {
        case .orderedSame:
          unstagedItem.change = stagedItem.change
          if unstagedItem.change == unstagedItem.unstagedChange &&
             (unstagedItem.change == .added ||
              unstagedItem.change == .deleted) {
            unstagedItem.unstagedChange = .unmodified
          }
          unstagedIndex += 1
          stagedIndex += 1
          if !unstagedNode.isLeaf || !stagedNode.isLeaf {
            combineTrees(unstagedTree: &unstagedNode, stagedTree: stagedNode)
          }
        case .orderedAscending:
          // Added in unstaged
          unstagedItem.change = .deleted
          unstagedIndex += 1
        case .orderedDescending:
          // Added in staged
          deletedItems.append(FileChange(path: stagedItem.path,
                                         change: stagedItem.change,
                                         unstagedChange: .deleted))
          stagedIndex += 1
      }
    }
    unstagedTree.mutableChildren.addObjects(from: deletedItems)
    unstagedTree.mutableChildren.sort(keyPath: "representedObject.path")
  }

  /// Adds the contents of one tree into another
  func add(_ srcTree: NSTreeNode, to destTree: inout NSTreeNode)
  {
    guard let srcNodes = srcTree.children
    else { return }
    guard let destNodes = destTree.children
    else { return }
    
    var srcIndex = 0, destIndex = 0
    var addedNodes = [NSTreeNode]()
    
    while (srcIndex < srcNodes.count) && (destIndex < destNodes.count) {
      let srcItem = srcNodes[srcIndex].representedObject! as! FileChange
      let destItem = destNodes[destIndex].representedObject! as! FileChange
      
      if destItem.path != srcItem.path {
        // NSTreeNode can't be in two trees, so make a new one.
        let newNode = NSTreeNode(representedObject:
            FileChange(path: srcItem.path,
                       change: .unmodified,
                       unstagedChange: .untracked))
        
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
