import XCTest
@testable import Xit

class XTFileChangesModelTest: XTTest
{  
  func data(for string: String) -> Data
  {
    return (string as NSString).data(using: String.Encoding.utf8.rawValue)!
  }
  
  func string(from data: Data) -> String
  {
    return NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
  }
  
  func testCommit()
  {
    guard let headSHA = repository.headSHA,
          let headCommit = XTCommit(sha: headSHA, repository: repository)
    else {
      XCTFail("no head")
      return
    }
    let model = CommitSelection(repository: repository, commit: headCommit)
    let changes = model.fileList.changes
    
    XCTAssertEqual(changes.count, 1)
    
    let change = changes[0]
    
    XCTAssertEqual(change.path, file1Name)
    XCTAssertEqual(change.change, DeltaStatus.added)
    
    let data = model.fileList.dataForFile(file1Name)
    
    XCTAssertEqual(data, self.data(for:"some text"))
    
    guard let diffResult = model.fileList.diffForFile(file1Name),
          let patch = diffResult.extractPatch()
    else {
      XCTFail()
      return
    }
    
    XCTAssertEqual(patch.addedLinesCount, 1)
  }
  
  func checkPatchLines(
      _ model: RepositorySelection, path: String, staged: Bool,
      added: Int, deleted: Int)
  {
    guard let diffResult = model.list(staged: staged).diffForFile(path),
          let patch = diffResult.extractPatch()
    else {
      XCTFail()
      return
    }
    
    XCTAssertEqual(patch.addedLinesCount, added,
        String(format: "%@%@", staged ? ">" : "<", path))
    XCTAssertEqual(patch.deletedLinesCount, deleted,
        String(format: "%@%@", staged ? ">" : "<", path))
  }
  
  func testStash()
  {
    self.makeStash()
    
    let model = StashSelection(repository: repository, index: 0)
    
    XCTAssertEqual(model.shaToSelect, repository.headSHA)
    
    let changes = model.fileList.changes
    let unstagedChanges = model.unstagedFilelist.changes
    
    XCTAssertEqual(changes.count, 1)
    XCTAssertEqual(unstagedChanges.count, 2)
    
    let addedContent =
        self.string(from: model.fileList.dataForFile(addedName)!)
    let untrackedContent =
        self.string(from: model.unstagedFilelist.dataForFile(untrackedName)!)
    let file1Unstaged =
        self.string(from: model.unstagedFilelist.dataForFile(file1Name)!)
    let file1Staged =
        self.string(from: model.fileList.dataForFile(file1Name)!)
    
    XCTAssertEqual(addedContent, "add")
    XCTAssertEqual(untrackedContent, "new")
    XCTAssertEqual(file1Unstaged, "stashy")
    XCTAssertEqual(file1Staged, "some text")
    XCTAssertNil(model.fileList.dataForFile(untrackedName))
    
    self.checkPatchLines(
        model, path: addedName, staged: true, added: 1, deleted: 0)
    self.checkPatchLines(
        model, path: addedName, staged: false, added: 0, deleted: 0)
    self.checkPatchLines(
        model, path: untrackedName, staged: false, added: 1, deleted: 0)
    self.checkPatchLines(
        model, path: file1Name, staged: false, added: 1, deleted: 1)
    self.checkPatchLines(
        model, path: file1Name, staged: true, added: 0, deleted: 0)
    XCTAssertNil(model.fileList.diffForFile(untrackedName))
  }
  
  func testStaging()
  {
    let model = StagingSelection(repository: repository)
    var changes = model.unstagedFilelist.changes
    
    XCTAssertEqual(changes.count, 0)
    
    self.writeText(toFile1: "change")
    changes = model.unstagedFilelist.changes
    XCTAssertEqual(changes.count, 1)
    
    guard !changes.isEmpty
    else {
      XCTFail("empty changes")
      return
    }
    var change = changes[0]
    
    XCTAssertEqual(change.path, file1Name)
    XCTAssertEqual(change.change, DeltaStatus.modified)
    
    self.writeText("new", toFile: addedName)
    changes = model.unstagedFilelist.changes
    XCTAssertEqual(changes.count, 2)
    guard !changes.isEmpty
    else {
      XCTFail("empty changes")
      return
    }
    change = changes[0] // "added" will be sorted to the top
    XCTAssertEqual(change.path, addedName)
    XCTAssertEqual(change.change, DeltaStatus.untracked)
    
    XCTAssertNoThrow(try repository.stage(file: addedName))
    XCTAssertEqual(model.unstagedFilelist.changes.count, 1)
    changes = model.fileList.changes
    XCTAssertEqual(changes.count, 1)
    guard !changes.isEmpty
    else {
      XCTFail("empty changes")
      return
    }
    change = changes[0]
    XCTAssertEqual(change.path, addedName)
    XCTAssertEqual(change.change, DeltaStatus.added)
  }
  
  func testStagingTreeSimple()
  {
    let model = StagingSelection(repository: repository)
    let tree = model.fileList.treeRoot(oldTree: nil)
    
    XCTAssertNotNil(tree.children)
    XCTAssertEqual(tree.children!.count, 1)
    
    let change = tree.children![0].representedObject as! FileChange
    
    XCTAssertEqual(change.change, DeltaStatus.unmodified)
  }
  
  func testCommitTree()
  {
    self.commitNewTextFile(addedName, content: "new")
    
    guard let headSHA = repository.headSHA,
          let headCommit = XTCommit(sha: headSHA, repository: repository)
      else {
        XCTFail("no head")
        return
    }
    let model = CommitSelection(repository: repository,
                              commit: headCommit)
    let tree = model.fileList.treeRoot(oldTree: nil)
    
    XCTAssertNotNil(tree.children)
    XCTAssertEqual(tree.children!.count, 2)
    
    var change = tree.children![0].representedObject as! FileChange
    
    XCTAssertEqual(change.path, addedName)
    XCTAssertEqual(change.change, DeltaStatus.added)
    
    change = tree.children![1].representedObject as! FileChange
    XCTAssertEqual(change.path, file1Name)
    XCTAssertEqual(change.change, DeltaStatus.unmodified)
  }
  
  func testStashTree()
  {
    let deletedName = "deleted"
    let deletedURL = repository.repoURL.appendingPathComponent(deletedName)
  
    self.commitNewTextFile(deletedName, content: "bye!")
    try! FileManager.default.removeItem(at: deletedURL)
    try! self.repository.stage(file: deletedName)
    
    self.makeStash()
    
    let model = StashSelection(repository: repository, index: 0)
    let tree = model.fileList.treeRoot(oldTree: nil)
    guard let children = tree.children
    else {
      XCTFail("no children")
      return
    }
    
    XCTAssertEqual(children.count, 4)
    
    let expectedPaths =
        [addedName,   deletedName, file1Name,   untrackedName]
    let expectedChanges: [DeltaStatus] =
        [.added,      .deleted,    .unmodified, .unmodified]
    let expectedUnstaged: [DeltaStatus] =
        [.unmodified, .unmodified, .modified,   .untracked]
    
    for i in 0..<min(4, children.count) {
      let item = children[i].representedObject as! FileChange
      
      XCTAssertEqual(item.path, expectedPaths[i])
      XCTAssertEqual(item.change, expectedChanges[i],
          "\(item.path) change: \(item.change.rawValue)")
      XCTAssertEqual(item.unstagedChange, expectedUnstaged[i],
          "\(item.path) unstaged: \(item.unstagedChange.rawValue)")
    }
  }
  
  // Checks that the results are the same whether you generate a tree from
  // scratch or use the parent as a starting point.
  func checkCommitTrees(deletedPath: String?)
  {
    guard let headSHA = repository.headSHA,
          let commit = repository.commit(forSHA: headSHA),
          let parentOID = commit.parentOIDs.first,
          let parent = repository.commit(forOID: parentOID)
    else {
      XCTFail("can't get commits")
      return
    }
    let parentModel = CommitSelection(repository: repository, commit: parent)
    let model = CommitSelection(repository: repository, commit: commit)
    let parentTree = parentModel.fileList.treeRoot(oldTree: nil)
    let tree1 = model.fileList.treeRoot(oldTree: nil)
    let tree2 = model.fileList.treeRoot(oldTree: parentTree)
    
    XCTAssertTrue(tree1.isEqual(tree2))
    
    if let deletedPath = deletedPath {
      let components = deletedPath.pathComponents
      var node = tree2
      
      for component in components {
        guard let children = node.children
        else {
          XCTFail("no children")
          break
        }
        
        if let child = children.first(where: { component ==
              ($0.representedObject as? CommitTreeItem)?.path.lastPathComponent }) {
          node = child
        }
        else {
          XCTFail("unmatched parent: \(component)")
          return
        }
      }
      
      guard let item = node.representedObject as? CommitTreeItem
      else {
        XCTFail("no item")
        return
      }
      
      XCTAssertEqual(item.change, DeltaStatus.deleted)
    }
    
    if deletedPath != file1Name {
      guard let file1Node = tree2.children?.first(where:
              { ($0.representedObject as? CommitTreeItem)?.path == file1Name} ),
            let item = file1Node.representedObject as? CommitTreeItem
      else {
        XCTFail("file1 missing")
        return
      }
      
      XCTAssertEqual(item.change, DeltaStatus.unmodified)
    }
  }
  
  func testCommitRootAddFile()
  {
    guard let headSHA1 = repository.headSHA,
          let commit1 = repository.commit(forSHA: headSHA1)
    else {
      XCTFail("no head commit")
      return
    }
    
    commitNewTextFile("file2", content: "text")
    
    guard let headSHA2 = repository.headSHA,
          let commit2 = repository.commit(forSHA: headSHA2)
    else {
      XCTFail("no head commit")
      return
    }
    
    let model1 = CommitSelection(repository: repository, commit: commit1)
    let model2 = CommitSelection(repository: repository, commit: commit2)
    
    let tree1 = model1.fileList.treeRoot(oldTree: nil)
    let tree2 = model2.fileList.treeRoot(oldTree: tree1)
    guard let children1 = tree1.children,
          let children2 = tree2.children
    else {
      XCTFail("no children")
      return
    }
    
    XCTAssertEqual(children1.count, 1)
    XCTAssertEqual(children2.count, 2)
    checkCommitTrees(deletedPath: nil)
  }
  
  func testCommitRootSubFile()
  {
    let subURL = repository.repoURL.appendingPathComponent("sub")
    
    XCTAssertNoThrow(try FileManager.default.createDirectory(
        at: subURL, withIntermediateDirectories: false, attributes: nil))
    commitNewTextFile("sub/file2", content: "text")
    
    checkCommitTrees(deletedPath: nil)
  }
  
  func testCommitRootDeleteSubFile()
  {
    let subDirName = "sub"
    let subFileName = "file2"
    let subFilePath = subDirName.appending(pathComponent: subFileName)
    let subURL = repository.repoURL.appendingPathComponent(subDirName)
    let subFileURL = subURL.appendingPathComponent(subFileName)
    
    XCTAssertNoThrow(try FileManager.default.createDirectory(
        at: subURL, withIntermediateDirectories: false, attributes: nil))
    commitNewTextFile(subFilePath, content: "text")
    
    XCTAssertNoThrow(try FileManager.default.removeItem(at: subFileURL))
    XCTAssertNoThrow(try repository.stage(file: subFilePath))
    XCTAssertNoThrow(try repository.commit(message: "delete", amend: false,
                                           outputBlock: nil))
    
    checkCommitTrees(deletedPath: subFilePath)
  }
  
  func testCommitRootDeleteSubSubFile()
  {
    let subDirName = "sub"
    let subFileName = "file2"
    let subFilePath = subDirName.appending(pathComponent: subDirName)
                                .appending(pathComponent: subFileName)
    let subURL = repository.repoURL.appendingPathComponent(subDirName)
    let subSubURL = subURL.appendingPathComponent(subDirName)
    let subFileURL = subSubURL.appendingPathComponent(subFileName)
    
    XCTAssertNoThrow(try FileManager.default.createDirectory(
        at: subSubURL, withIntermediateDirectories: true, attributes: nil))
    commitNewTextFile(subFilePath, content: "text")
    
    XCTAssertNoThrow(try FileManager.default.removeItem(at: subFileURL))
    XCTAssertNoThrow(try repository.stage(file: subFilePath))
    XCTAssertNoThrow(try repository.commit(message: "delete", amend: false,
                                           outputBlock: nil))
    
    checkCommitTrees(deletedPath: subFilePath)
  }
  
  func testCommitRootDeleteRootFile()
  {
    let subDirName = "sub"
    let subFileName = "file2"
    let subFilePath = subDirName.appending(pathComponent: subFileName)
    let subURL = repository.repoURL.appendingPathComponent(subDirName)
    
    XCTAssertNoThrow(try FileManager.default.createDirectory(
      at: subURL, withIntermediateDirectories: false, attributes: nil))
    commitNewTextFile(subFilePath, content: "text")
    
    XCTAssertNoThrow(try FileManager.default.removeItem(
        at: repository.repoURL.appendingPathComponent(file1Name)))
    XCTAssertNoThrow(try repository.stage(file: file1Name))
    XCTAssertNoThrow(try repository.commit(message: "delete", amend: false,
                                           outputBlock: nil))
    
    checkCommitTrees(deletedPath: file1Name)
  }
  
  func makeSubFolderCommits() -> (Commit, Commit)?
  {
    let subDirName = "sub"
    let subFileName = "file2"
    let subFilePath = subDirName.appending(pathComponent: subFileName)
    let subURL = repository.repoURL.appendingPathComponent(subDirName)
    
    // Add a file to a subfolder, and save the tree from that commit
    XCTAssertNoThrow(try FileManager.default.createDirectory(
        at: subURL, withIntermediateDirectories: false, attributes: nil))
    commitNewTextFile(subFilePath, content: "text")
    
    guard let parentCommit = repository.headSHA.flatMap(
                { repository.commit(forSHA: $0) })
    else {
      XCTFail("can't get parent commit")
      return nil
    }

    // Make a new commit where that subfolder is unchanged
    writeText(toFile1: "changes")
    XCTAssertNoThrow(try repository.stage(file: file1Name))
    XCTAssertNoThrow(try repository.commit(message: "commit 3", amend: false,
                                           outputBlock: nil))
    
    guard let headSHA = repository.headSHA,
          let commit = repository.commit(forSHA: headSHA)
    else {
      XCTFail("can't get commit")
      return nil
    }
    
    return (parentCommit, commit)
  }
  
  // Make sure that when a subtree is copied from an old tree, its statuses
  // are updated.
  func testCommitRootUpdateUnchanged()
  {
    guard let (parentCommit, commit) = makeSubFolderCommits()
    else { return }
    
    let subDirName = "sub"
    let subFileName = "file2"
    let subFilePath = subDirName.appending(pathComponent: subFileName)
    
    let parentModel = CommitSelection(repository: repository, commit: parentCommit)
    let parentRoot = parentModel.fileList.treeRoot(oldTree: nil)
    
    // Double check that the file shows up as added
    guard let newNode = parentRoot.commitTreeItemNode(forPath: subFilePath),
          let newItem = newNode.representedObject as? CommitTreeItem
    else {
      XCTFail("can't get item")
      return
    }
    
    XCTAssertEqual(newItem.change, DeltaStatus.added)
    
    let model = CommitSelection(repository: repository, commit: commit)
    let root = model.fileList.treeRoot(oldTree: parentRoot)
    guard let fileNode = root.commitTreeItemNode(forPath: subFilePath),
          let item = fileNode.representedObject as? CommitTreeItem
    else {
      XCTFail("can't get item")
      return
    }
    
    XCTAssertEqual(item.change, DeltaStatus.unmodified)
  }
  
  // Like testCommitRootUpdateUnchanged but going the other way
  func testCommitRootUpdateReversed()
  {
    guard let (parentCommit, commit) = makeSubFolderCommits()
    else { return }
    
    let subDirName = "sub"
    let subFileName = "file2"
    let subFilePath = subDirName.appending(pathComponent: subFileName)

    let model = CommitSelection(repository: repository, commit: commit)
    let root = model.fileList.treeRoot(oldTree: nil)
    guard let fileNode = root.commitTreeItemNode(forPath: subFilePath),
          let item = fileNode.representedObject as? CommitTreeItem
    else {
      XCTFail("can't get item")
      return
    }
    
    XCTAssertEqual(item.change, DeltaStatus.unmodified)
    
    let parentModel = CommitSelection(repository: repository, commit: parentCommit)
    let parentRoot = parentModel.fileList.treeRoot(oldTree: root)
    
    guard let newNode = parentRoot.commitTreeItemNode(forPath: subFilePath),
      let newItem = newNode.representedObject as? CommitTreeItem
      else {
        XCTFail("can't get item")
        return
    }
    
    XCTAssertEqual(newItem.change, DeltaStatus.added)
  }
}

extension NSTreeNode
{
  /// Compares the contents of two tree nodes. This fails if either one has
  /// a nil `representedObject`, but that's fine for testing purposes.
  open override func isEqual(_ object: Any?) -> Bool
  {
    guard let otherNode = object as? NSTreeNode,
          let representedObject = self.representedObject as? NSObject,
          let otherObject = otherNode.representedObject as? NSObject,
          representedObject.isEqual(otherObject),
          let children = self.children,
          let otherChildren = otherNode.children,
          children.count == otherChildren.count
    else { return false }
    
    for (child, otherChild) in zip(children, otherChildren) {
      if !child.isEqual(otherChild) {
        return false
      }
    }
    return true
  }
  
  func commitTreeItemNode(forPath path: String, root: String = "") -> NSTreeNode?
  {
    let relativePath = path.removingPrefix(root + "/")
    guard let topFolderName = relativePath.firstPathComponent
    else { return nil }
    let folderPath = root.appending(pathComponent: topFolderName)
    guard let node = children?.first(where:
                { ($0.representedObject as? CommitTreeItem)?.path == folderPath}),
          let item = node.representedObject as? CommitTreeItem
    else { return nil }
    
    if item.path == path {
      return node
    }
    else {
      return node.commitTreeItemNode(forPath: path, root: folderPath)
    }
  }
  
  func printChangeItems()
  {
    if let item = representedObject as? CommitTreeItem {
      print("\(item.path) - \(item.change)/\(item.unstagedChange)")
    }
    if let children = self.children {
      for child in children {
        child.printChangeItems()
      }
    }
  }
}
