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
  func diffForFile(path: String, staged: Bool) -> XTDiffDelta?
  /// Get the contents of the given file.
  /// - parameter path: Repository-relative file path.
  /// - parameter staged: Whether to show the staged or unstaged diff. Ignored
  /// for models that don't have unstaged files.
  func dataForFile(path: String, staged: Bool) -> NSData?
  /// The URL of the unstaged file, if any.
  func unstagedFileURL(path: String) -> NSURL?
}


/// Changes for a selected commit in the history
class XTCommitChanges: NSObject, XTFileChangesModel {
  var repository: XTRepository
  var sha: String
  var shaToSelect: String? { return self.sha }
  var hasUnstaged: Bool { return false }
  var canCommit: Bool { return false }
  
  var changes: [XTFileChange]
  {
    return self.repository.changesForRef(self.sha, parent: self.diffParent) ??
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
  
  func diffForFile(path: String, staged: Bool) -> XTDiffDelta?
  {
    return self.repository.diffForFile(
        path, commitSHA: self.sha, parentSHA: self.diffParent)
  }
  
  func dataForFile(path: String, staged: Bool) -> NSData?
  {
    return self.repository.contentsOfFile(path, atCommit: self.sha)
  }
  
  func unstagedFileURL(path: String) -> NSURL? { return nil }

  func makeTreeRoot(staged staged: Bool) -> NSTreeNode
  {
    var files = repository.fileNamesForRef(sha) ?? [String]()
    var changes = [String: XitChange]()
    
    if let changeList = repository.changesForRef(sha, parent:diffParent) {
      for change in changeList {
        changes[change.path] = change.change
      }
      files.appendContentsOf(
          changeList.filter({ return $0.change == .Deleted })
                    .map({ return $0.path }))
    }
    
    let newRoot = NSTreeNode(representedObject: XTCommitTreeItem(path:"/"))
    var nodes = [String: NSTreeNode]()
    
    for file in files {
      let changeValue = changes[file] ?? .Unmodified
      let item = staged ?
          XTCommitTreeItem(path: file, change: changeValue) :
          XTCommitTreeItem(path: file,
                           change: .Unmodified,
                           unstagedChange: changeValue)
      let parentPath = (file as NSString).stringByDeletingLastPathComponent
      let node = NSTreeNode(representedObject: item)
      let parentNode = XTChangesModelUtils.findTreeNode(
          forPath: parentPath, parent: newRoot, nodes: &nodes)
      
      parentNode.mutableChildNodes.addObject(node)
      nodes[file] = node
    }
    XTChangesModelUtils.postProcess(fileTree: newRoot)
    return newRoot
  }
}


/// Changes for a selected stash, merging workspace, index, and untracked
class XTStashChanges: NSObject, XTFileChangesModel {
  var repository: XTRepository
  var stash: XTStash
  var hasUnstaged: Bool { return true }
  var canCommit: Bool { return false }
  var shaToSelect: String? { return stash.mainCommit.parents[0].SHA }
  var changes: [XTFileChange] { return self.stash.changes() }
  
  var treeRoot: NSTreeNode {
    let mainModel = XTCommitChanges(repository: repository,
                                    sha: stash.mainCommit.SHA!)
    var mainRoot = mainModel.makeTreeRoot(staged: false)
    
    if let indexCommit = stash.indexCommit {
      let indexModel = XTCommitChanges(repository: repository,
                                       sha: indexCommit.SHA!)
      let indexRoot = indexModel.treeRoot
      
      XTChangesModelUtils.combineTrees(unstagedTree: &mainRoot,
                                      stagedTree: indexRoot)
    }
    if let untrackedCommit = stash.untrackedCommit {
      let untrackedModel = XTCommitChanges(repository: repository,
                                           sha: untrackedCommit.SHA!)
      let untrackedRoot = untrackedModel.treeRoot
    
      XTChangesModelUtils.add(untrackedRoot, to: &mainRoot)
    }
    return mainRoot
  }
  
  init(repository: XTRepository, index: UInt)
  {
    self.repository = repository
    self.stash = XTStash(repo: repository, index: index)
    
    super.init()
  }
  
  func diffForFile(path: String, staged: Bool) -> XTDiffDelta?
  {
    if staged {
      return self.stash.stagedDiffForFile(path)
    }
    else {
      return self.stash.unstagedDiffForFile(path)
    }
  }
  
  func dataForFile(path: String, staged: Bool) -> NSData?
  {
    if staged {
      guard let indexCommit = self.stash.indexCommit
      else { return nil }
      
      return self.repository.contentsOfFile(path, atCommit: indexCommit.SHA)
    }
    else {
      if let untrackedCommit = self.stash.untrackedCommit,
         let untrackedData = self.repository.contentsOfFile(path, atCommit: untrackedCommit.SHA) {
        return untrackedData
      }
      return self.repository.contentsOfFile(
          path, atCommit: self.stash.mainCommit.SHA)
    }
  }

  // Unstaged files are stored in commits, so there is no URL.
  func unstagedFileURL(path: String) -> NSURL? { return nil }
}


/// Staged and unstaged workspace changes
class XTStagingChanges: NSObject, XTFileChangesModel {
  var repository: XTRepository
  var shaToSelect: String? { return XTStagingSHA }
  var hasUnstaged: Bool { return true }
  var canCommit: Bool { return true }
  var changes: [XTFileChange]
    { return repository.changesForRef(XTStagingSHA, parent: nil) ?? [] }
  
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
  
  func diffForFile(path: String, staged: Bool) -> XTDiffDelta?
  {
    if staged {
      return self.repository.stagedDiffForFile(path)
    }
    else {
      return self.repository.unstagedDiffForFile(path)
    }
  }
  
  func dataForFile(path: String, staged: Bool) -> NSData?
  {
    if staged {
      return self.repository.contentsOfStagedFile(path)
    }
    else {
      let url = self.repository.repoURL.URLByAppendingPathComponent(path)
      
      return NSData(contentsOfURL: url)
    }
  }
  
  func unstagedFileURL(path: String) -> NSURL?
  {
    return self.repository.repoURL.URLByAppendingPathComponent(path)
  }
}


private class XTChangesModelUtils {
  
  /// Sets folder change status to match children.
  class func postProcess(fileTree tree: NSTreeNode)
  {
    let sortDescriptor = NSSortDescriptor(
        key: "path.lastPathComponent",
        ascending: true,
        selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
    
    tree.sortWithSortDescriptors([sortDescriptor], recursively: true)
    updateChanges(tree)
  }

  /// Recursive helper for `postProcess`.
  class func updateChanges(node: NSTreeNode)
  {
    guard let childNodes = node.childNodes
    else { return }
    
    var change: XitChange?, unstagedChange: XitChange?
    
    for child in childNodes {
      let childItem = child.representedObject as! XTCommitTreeItem
      
      if !child.leaf {
        updateChanges(child)
      }
      
      if (change == nil) {
        change = childItem.change
      }
      else if change! != childItem.change {
        change = XitChange.Mixed
      }
      
      if (unstagedChange == nil) {
        unstagedChange = childItem.unstagedChange
      }
      else if unstagedChange! != childItem.unstagedChange {
        unstagedChange = XitChange.Mixed
      }
    }
    
    let nodeItem = node.representedObject as! XTCommitTreeItem
    
    nodeItem.change = change ?? .Unmodified
    nodeItem.unstagedChange = unstagedChange ?? .Unmodified
  }

  class func findTreeNode(
      forPath path: String,
      parent: NSTreeNode,
      inout nodes: [String: NSTreeNode]) -> NSTreeNode
  {
    guard !path.isEmpty
    else { return parent }
    
    if let pathNode = nodes[path] {
      return pathNode
    }
    else {
      let pathNode = NSTreeNode(representedObject: XTCommitTreeItem(path: path))
      let parentPath = (path as NSString).stringByDeletingLastPathComponent
      
      parent.mutableChildNodes.addObject((parentPath.isEmpty) ?
          pathNode :
          findTreeNode(forPath: parentPath, parent: parent, nodes: &nodes))
      nodes[path] = pathNode
      return pathNode
    }
  }

  /// Merges a tree of unstaged changes into a tree of staged changes.
  class func combineTrees(
      inout unstagedTree unstagedTree: NSTreeNode,
      stagedTree: NSTreeNode)
  {
    // Not sure if these should be expected
    guard let unstagedNodes = unstagedTree.childNodes
    else {
      NSLog("combineTrees: no unstaged children at %@",
            unstagedTree.representedObject!.path)
      return
    }
    guard let stagedNodes = stagedTree.childNodes
    else {
      NSLog("combineTrees: no staged children at %@",
            stagedTree.representedObject!.path)
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
        case .OrderedSame:
          unstagedItem.change = stagedItem.change
          if unstagedItem.change == unstagedItem.unstagedChange &&
             (unstagedItem.change == .Added ||
              unstagedItem.change == .Deleted) {
            unstagedItem.unstagedChange = .Unmodified
          }
          unstagedIndex += 1
          stagedIndex += 1
          if !unstagedNode.leaf || !stagedNode.leaf {
            combineTrees(unstagedTree: &unstagedNode, stagedTree: stagedNode)
          }
        case .OrderedAscending:
          // Added in unstaged
          unstagedItem.change = .Deleted
          unstagedIndex += 1
        case .OrderedDescending:
          // Added in staged
          deletedItems.append(XTFileChange(path: stagedItem.path,
                                           change: stagedItem.change,
                                           unstagedChange: .Deleted))
          stagedIndex += 1
      }
    }
    unstagedTree.mutableChildNodes.addObjectsFromArray(deletedItems)
    unstagedTree.mutableChildNodes.sort(keyPath: "representedObject.path")
  }

  /// Adds the contents of one tree into another
  class func add(srcTree: NSTreeNode, inout to destTree: NSTreeNode)
  {
    guard let srcNodes = srcTree.childNodes
    else { return }
    guard let destNodes = destTree.childNodes
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
                         change: .Unmodified,
                         unstagedChange: .Untracked))
        
        newNode.mutableChildNodes.addObjectsFromArray(srcNodes[srcIndex].childNodes!)
        addedNodes.append(newNode)
      }
      else {
        destIndex += 1
      }
      srcIndex += 1
    }
    destTree.mutableChildNodes.addObjectsFromArray(addedNodes)
    destTree.mutableChildNodes.sort(keyPath: "representedObject.path")
  }
}

extension NSMutableArray {
  func sort(keyPath key: String, ascending: Bool = true)
  {
    sortUsingDescriptors([NSSortDescriptor(key: key, ascending: ascending)])
  }
}
