import Cocoa

/**
 * Protocol for a commit or commit-like object,
 * with metadata, files, and diffs.
 */
@objc protocol XTFileChangesModel {
  var repository: XTRepository { get set }
  /// SHA for commit to be selected in the history list
  var shaToSelect: String? { get }
  /// Changes displayed in the file list
  var changes: [XTFileChange] { get }
  /// Top level of the file tree
  var treeRoot: NSTreeNode { get }
  /// Are there staged and unstaged changes?
  var hasUnstaged: Bool { get }
  /// Is this used to stage and commit files?
  var canCommit: Bool { get }
  /// Get the diff for the given file.
  /// - parameter path: Repository-relative file path.
  /// - parameter staged: Whether to show the staged or unstaged diff. Ignored
  /// for models that don't have unstaged files.
  func diffForFile(_ path: String, staged: Bool) -> XTDiffDelta?
  /// Get the contents of the given file.
  /// - parameter path: Repository-relative file path.
  /// - parameter staged: Whether to show the staged or unstaged diff. Ignored
  /// for models that don't have unstaged files.
  func dataForFile(_ path: String, staged: Bool) -> Data?
  /// The URL of the unstaged file, if any.
  func unstagedFileURL(_ path: String) -> URL?
}


/// Changes for a selected commit in the history
class XTCommitChanges: NSObject, XTFileChangesModel
{
  unowned var repository: XTRepository
  var sha: String
  var shaToSelect: String? { return self.sha }
  var hasUnstaged: Bool { return false }
  var canCommit: Bool { return false }
  
  var changes: [XTFileChange]
  {
    return self.repository.changes(forRef: self.sha, parent: self.diffParent) ??
        [XTFileChange]()
  }
  
  var treeRoot: NSTreeNode
  {
    return self.makeTreeRoot(staged:true)
  }
  
  /// SHA of the parent commit to use for diffs
  var diffParent: String?
  
  init(repository: XTRepository, sha: String)
  {
    self.repository = repository
    self.sha = sha
    
    super.init()
  }
  
  func diffForFile(_ path: String, staged: Bool) -> XTDiffDelta?
  {
    return self.repository.diff(
        forFile: path, commitSHA: self.sha, parentSHA: self.diffParent)
  }
  
  func dataForFile(_ path: String, staged: Bool) -> Data?
  {
    return try? self.repository.contents(ofFile: path, atCommit: self.sha)
  }
  
  func unstagedFileURL(_ path: String) -> URL? { return nil }

  func makeTreeRoot(staged: Bool) -> NSTreeNode
  {
    var files = repository.fileNames(forRef: sha) ?? [String]()
    var changes = [String: XitChange]()
    
    if let changeList = repository.changes(forRef: sha, parent:diffParent) {
      for change in changeList {
        changes[change.path] = change.change
      }
      files.append(
          contentsOf: changeList.filter({ return $0.change == .deleted })
                    .map({ return $0.path }))
    }
    
    let newRoot = NSTreeNode(representedObject: XTCommitTreeItem(path:"/"))
    var nodes = [String: NSTreeNode]()
    
    for file in files {
      let changeValue = changes[file] ?? .unmodified
      let item = staged ?
          XTCommitTreeItem(path: file, change: changeValue) :
          XTCommitTreeItem(path: file,
                           change: .unmodified,
                           unstagedChange: changeValue)
      let parentPath = (file as NSString).deletingLastPathComponent
      let node = NSTreeNode(representedObject: item)
      let parentNode = XTChangesModelUtils.findTreeNode(
          forPath: parentPath, parent: newRoot, nodes: &nodes)
      
      parentNode.mutableChildren.add(node)
      nodes[file] = node
    }
    XTChangesModelUtils.postProcess(fileTree: newRoot)
    return newRoot
  }
}


/// Changes for a selected stash, merging workspace, index, and untracked
class XTStashChanges: NSObject, XTFileChangesModel
{
  unowned var repository: XTRepository
  var stash: XTStash
  var hasUnstaged: Bool { return true }
  var canCommit: Bool { return false }
  var shaToSelect: String? { return stash.mainCommit.parents[0].sha }
  var changes: [XTFileChange] { return self.stash.changes() }
  
  var treeRoot: NSTreeNode {
    let mainModel = XTCommitChanges(repository: repository,
                                    sha: stash.mainCommit.sha!)
    var mainRoot = mainModel.makeTreeRoot(staged: false)
    
    if let indexCommit = stash.indexCommit {
      let indexModel = XTCommitChanges(repository: repository,
                                       sha: indexCommit.sha!)
      let indexRoot = indexModel.treeRoot
      
      XTChangesModelUtils.combineTrees(unstagedTree: &mainRoot,
                                      stagedTree: indexRoot)
    }
    if let untrackedCommit = stash.untrackedCommit {
      let untrackedModel = XTCommitChanges(repository: repository,
                                           sha: untrackedCommit.sha!)
      let untrackedRoot = untrackedModel.treeRoot
    
      XTChangesModelUtils.add(untrackedRoot, to: &mainRoot)
    }
    return mainRoot
  }
  
  init(repository: XTRepository, index: UInt)
  {
    self.repository = repository
    self.stash = XTStash(repo: repository, index: index, message: nil)
    
    super.init()
  }
  
  init(repository: XTRepository, stash: XTStash)
  {
    self.repository = repository
    self.stash = stash
    
    super.init()
  }
  
  func diffForFile(_ path: String, staged: Bool) -> XTDiffDelta?
  {
    if staged {
      return self.stash.stagedDiffForFile(path)
    }
    else {
      return self.stash.unstagedDiffForFile(path)
    }
  }
  
  func dataForFile(_ path: String, staged: Bool) -> Data?
  {
    if staged {
      guard let indexCommit = self.stash.indexCommit
      else { return nil }
      
      return try? self.repository.contents(ofFile: path, atCommit: indexCommit.sha!)
    }
    else {
      if let untrackedCommit = self.stash.untrackedCommit,
         let untrackedData = try? self.repository.contents(
             ofFile: path, atCommit: untrackedCommit.sha!) {
        return untrackedData
      }
      return try? self.repository.contents(
          ofFile: path, atCommit: self.stash.mainCommit.sha!)
    }
  }

  // Unstaged files are stored in commits, so there is no URL.
  func unstagedFileURL(_ path: String) -> URL? { return nil }
}


/// Staged and unstaged workspace changes
class XTStagingChanges: NSObject, XTFileChangesModel
{
  unowned var repository: XTRepository
  var shaToSelect: String? { return XTStagingSHA }
  var hasUnstaged: Bool { return true }
  var canCommit: Bool { return true }
  var changes: [XTFileChange]
    { return repository.changes(forRef: XTStagingSHA, parent: nil) ?? [] }
  
  var treeRoot: NSTreeNode
  {
    let builder = XTWorkspaceTreeBuilder(changes: repository.workspaceStatus)
    let root = builder.build(repository.repoURL)
    
    XTChangesModelUtils.postProcess(fileTree: root)
    return root
  }
  
  init(repository: XTRepository)
  {
    self.repository = repository
    
    super.init()
  }
  
  func diffForFile(_ path: String, staged: Bool) -> XTDiffDelta?
  {
    if staged {
      return self.repository.stagedDiff(forFile: path)
    }
    else {
      return self.repository.unstagedDiff(forFile: path)
    }
  }
  
  func dataForFile(_ path: String, staged: Bool) -> Data?
  {
    if staged {
      return try? self.repository.contents(ofStagedFile: path)
    }
    else {
      let url = self.repository.repoURL.appendingPathComponent(path)
      
      return try? Data(contentsOf: url)
    }
  }
  
  func unstagedFileURL(_ path: String) -> URL?
  {
    return self.repository.repoURL.appendingPathComponent(path)
  }
}


private class XTChangesModelUtils
{
  /// Sets folder change status to match children.
  class func postProcess(fileTree tree: NSTreeNode)
  {
    let sortDescriptor = NSSortDescriptor(
        key: "path.lastPathComponent",
        ascending: true,
        selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
    
    tree.sort(with: [sortDescriptor], recursively: true)
    updateChanges(tree)
  }

  /// Recursive helper for `postProcess`.
  class func updateChanges(_ node: NSTreeNode)
  {
    guard let childNodes = node.children
    else { return }
    
    var change: XitChange?, unstagedChange: XitChange?
    
    for child in childNodes {
      let childItem = child.representedObject as! XTCommitTreeItem
      
      if !child.isLeaf {
        updateChanges(child)
      }
      
      if (change == nil) {
        change = childItem.change
      }
      else if change! != childItem.change {
        change = XitChange.mixed
      }
      
      if (unstagedChange == nil) {
        unstagedChange = childItem.unstagedChange
      }
      else if unstagedChange! != childItem.unstagedChange {
        unstagedChange = XitChange.mixed
      }
    }
    
    let nodeItem = node.representedObject as! XTCommitTreeItem
    
    nodeItem.change = change ?? .unmodified
    nodeItem.unstagedChange = unstagedChange ?? .unmodified
  }

  class func findTreeNode(
      forPath path: String,
      parent: NSTreeNode,
      nodes: inout [String: NSTreeNode]) -> NSTreeNode
  {
    guard !path.isEmpty
    else { return parent }
    
    if let pathNode = nodes[path] {
      return pathNode
    }
    else {
      let pathNode = NSTreeNode(representedObject: XTCommitTreeItem(path: path))
      let parentPath = (path as NSString).deletingLastPathComponent
      
      parent.mutableChildren.add((parentPath.isEmpty) ?
          pathNode :
          findTreeNode(forPath: parentPath, parent: parent, nodes: &nodes))
      nodes[path] = pathNode
      return pathNode
    }
  }

  /// Merges a tree of unstaged changes into a tree of staged changes.
  class func combineTrees(
      unstagedTree: inout NSTreeNode,
      stagedTree: NSTreeNode)
  {
    // Not sure if these should be expected
    guard let unstagedNodes = unstagedTree.children
    else {
      NSLog("combineTrees: no unstaged children at %@",
            (unstagedTree.representedObject! as AnyObject).path)
      return
    }
    guard let stagedNodes = stagedTree.children
    else {
      NSLog("combineTrees: no staged children at %@",
            (stagedTree.representedObject! as AnyObject).path)
      return
    }
    
    // Do a parallel iteration to more efficiently find additions & deletions.
    var unstagedIndex = 0, stagedIndex = 0;
    var deletedItems = [XTFileChange]()
    
    while (unstagedIndex < unstagedNodes.count) &&
          (stagedIndex < stagedNodes.count) {
      var unstagedNode = unstagedNodes[unstagedIndex]
      let unstagedItem = unstagedNode.representedObject! as! XTFileChange
      let stagedNode = stagedNodes[stagedIndex]
      let stagedItem = stagedNode.representedObject! as! XTFileChange
      
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
          deletedItems.append(XTFileChange(path: stagedItem.path,
                                           change: stagedItem.change,
                                           unstagedChange: .deleted))
          stagedIndex += 1
      }
    }
    unstagedTree.mutableChildren.addObjects(from: deletedItems)
    unstagedTree.mutableChildren.sort(keyPath: "representedObject.path")
  }

  /// Adds the contents of one tree into another
  class func add(_ srcTree: NSTreeNode, to destTree: inout NSTreeNode)
  {
    guard let srcNodes = srcTree.children
    else { return }
    guard let destNodes = destTree.children
    else { return }
    
    var srcIndex = 0, destIndex = 0
    var addedNodes = [NSTreeNode]()
    
    while (srcIndex < srcNodes.count) && (destIndex < destNodes.count) {
      let srcItem = srcNodes[srcIndex].representedObject! as! XTFileChange
      let destItem = destNodes[destIndex].representedObject! as! XTFileChange
      
      if (destItem.path != srcItem.path) {
        // NSTreeNode can't be in two trees, so make a new one.
        let newNode = NSTreeNode(representedObject:
            XTFileChange(path: srcItem.path,
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

extension NSMutableArray
{
  func sort(keyPath key: String, ascending: Bool = true)
  {
    self.sort(using: [NSSortDescriptor(key: key, ascending: ascending)])
  }
}
