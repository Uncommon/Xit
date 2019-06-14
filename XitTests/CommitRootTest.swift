import XCTest
@testable import Xit

class CommitRootTest: XTTest
{
  let subDirName = "sub"
  let subFileNameA = "fileA"
  let subFileNameB = "fileB"

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
    let scratchTree = model.fileList.treeRoot(oldTree: nil)
    let relativeTree = model.fileList.treeRoot(oldTree: parentTree)
    
    XCTAssertTrue(scratchTree.isEqual(relativeTree))
    
    if let deletedPath = deletedPath {
      let components = deletedPath.pathComponents
      var node = relativeTree
      
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
          XCTFail("unmatched child: \(component)")
          return
        }
      }
      
      guard let item = node.representedObject as? CommitTreeItem
      else {
        XCTFail("no item")
        return
      }
      
      XCTAssertEqual(item.status, DeltaStatus.deleted)
    }
    
    if deletedPath != FileName.file1 {
      guard let file1Node = relativeTree.children?.first(where:
              { ($0.representedObject as? CommitTreeItem)?.path == FileName.file1} ),
            let item = file1Node.representedObject as? CommitTreeItem
      else {
        XCTFail("file1 missing")
        return
      }
      
      XCTAssertEqual(item.status, DeltaStatus.unmodified)
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
    
    commit(newTextFile: "file2", content: "text")
    
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
    commit(newTextFile: "sub/file2", content: "text")
    
    checkCommitTrees(deletedPath: nil)
  }
  
  func testCommitRootDeleteSubFile()
  {
    let subFilePathA = subDirName +/ subFileNameA
    let subFilePathB = subDirName +/ subFileNameB
    let subURL = repository.repoURL +/ subDirName
    let subFileURL = subURL +/ subFileNameA
    
    XCTAssertNoThrow(try FileManager.default.createDirectory(
        at: subURL, withIntermediateDirectories: false, attributes: nil))
    commit(newTextFile: subFilePathA, content: "text")
    commit(newTextFile: subFilePathB, content: "bbbb")
    
    XCTAssertNoThrow(try FileManager.default.removeItem(at: subFileURL))
    XCTAssertNoThrow(try repository.stage(file: subFilePathA))
    XCTAssertNoThrow(try repository.commit(message: "delete", amend: false))
    
    checkCommitTrees(deletedPath: subFilePathA)
  }
  
  func testCommitRootDeleteSubSubFile()
  {
    let subFilePathA = subDirName +/ subDirName +/ subFileNameA
    let subFilePathB = subDirName +/ subDirName +/ subFileNameB
    let subURL = repository.repoURL +/ subDirName
    let subSubURL = subURL +/ subDirName
    let subFileURL = subSubURL +/ subFileNameA
    
    XCTAssertNoThrow(try FileManager.default.createDirectory(
        at: subSubURL, withIntermediateDirectories: true, attributes: nil))
    commit(newTextFile: subFilePathA, content: "text")
    commit(newTextFile: subFilePathB, content: "bbbb")

    XCTAssertNoThrow(try FileManager.default.removeItem(at: subFileURL))
    XCTAssertNoThrow(try repository.stage(file: subFilePathA))
    XCTAssertNoThrow(try repository.commit(message: "delete", amend: false))
    
    checkCommitTrees(deletedPath: subFilePathA)
  }
  
  func testCommitRootDeleteRootFile()
  {
    let subFilePathA = subDirName +/ subFileNameA
    let subURL = repository.repoURL +/ subDirName
    
    XCTAssertNoThrow(try FileManager.default.createDirectory(
        at: subURL, withIntermediateDirectories: false, attributes: nil))
    commit(newTextFile: subFilePathA, content: "text")
    
    XCTAssertNoThrow(try FileManager.default.removeItem(
        at: repository.repoURL +/ FileName.file1))
    XCTAssertNoThrow(try repository.stage(file: FileName.file1))
    XCTAssertNoThrow(try repository.commit(message: "delete", amend: false))
    
    checkCommitTrees(deletedPath: FileName.file1)
  }
  
  func makeSubFolderCommits() -> (Commit, Commit)?
  {
    let subFilePath = subDirName +/ subFileNameA
    let subURL = repository.repoURL +/ subDirName
    
    // Add a file to a subfolder, and save the tree from that commit
    XCTAssertNoThrow(try FileManager.default.createDirectory(
        at: subURL, withIntermediateDirectories: false, attributes: nil))
    commit(newTextFile: subFilePath, content: "text")
    
    guard let parentCommit = repository.headSHA.flatMap(
        { repository.commit(forSHA: $0) })
    else {
      XCTFail("can't get parent commit")
      return nil
    }
    
    // Make a new commit where that subfolder is unchanged
    writeTextToFile1("changes")
    XCTAssertNoThrow(try repository.stage(file: FileName.file1))
    XCTAssertNoThrow(try repository.commit(message: "commit 3", amend: false))
    
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
    
    let subFilePath = subDirName +/ subFileNameA
    
    let parentModel = CommitSelection(repository: repository, commit: parentCommit)
    let parentRoot = parentModel.fileList.treeRoot(oldTree: nil)
    
    // Double check that the file shows up as added
    guard let newNode = parentRoot.commitTreeItemNode(forPath: subFilePath),
          let newItem = newNode.representedObject as? CommitTreeItem
    else {
      XCTFail("can't get item")
      return
    }
    
    XCTAssertEqual(newItem.status, DeltaStatus.added)
    
    let model = CommitSelection(repository: repository, commit: commit)
    let root = model.fileList.treeRoot(oldTree: parentRoot)
    guard let fileNode = root.commitTreeItemNode(forPath: subFilePath),
          let item = fileNode.representedObject as? CommitTreeItem
    else {
      XCTFail("can't get item")
      return
    }
    
    XCTAssertEqual(item.status, DeltaStatus.unmodified)
  }
  
  // Like testCommitRootUpdateUnchanged but going the other way
  func testCommitRootUpdateReversed()
  {
    guard let (parentCommit, commit) = makeSubFolderCommits()
    else { return }
    
    let subFilePath = subDirName +/ subFileNameA
    
    let model = CommitSelection(repository: repository, commit: commit)
    let root = model.fileList.treeRoot(oldTree: nil)
    guard let fileNode = root.commitTreeItemNode(forPath: subFilePath),
          let item = fileNode.representedObject as? CommitTreeItem
    else {
      XCTFail("can't get item")
      return
    }
    
    XCTAssertEqual(item.status, DeltaStatus.unmodified)
    
    let parentModel = CommitSelection(repository: repository, commit: parentCommit)
    let parentRoot = parentModel.fileList.treeRoot(oldTree: root)
    
    guard let newNode = parentRoot.commitTreeItemNode(forPath: subFilePath),
          let newItem = newNode.representedObject as? CommitTreeItem
    else {
      XCTFail("can't get item")
      return
    }
    
    XCTAssertEqual(newItem.status, DeltaStatus.added)
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
    let folderPath = root +/ topFolderName
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
      print("\(item.path) - \(item.status)")
    }
    if let children = self.children {
      for child in children {
        child.printChangeItems()
      }
    }
  }
}
