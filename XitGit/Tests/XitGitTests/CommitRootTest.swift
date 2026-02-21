import XCTest
@testable import XitGit

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
    
    XCTAssertTrue(scratchTree.deepEquals(other: relativeTree))

    if let deletedPath = deletedPath {
      let components = deletedPath.pathComponents
      var node = relativeTree
      
      for component in components {
        let children = node.children

        if let child = children.first(where: { component ==
            $0.value.path.lastPathComponent }) {
          node = child
        }
        else {
          XCTFail("unmatched child: \(component)")
          return
        }
      }
      
      XCTAssertEqual(node.value.status, DeltaStatus.deleted)
    }
    
    if deletedPath != TestFileName.file1 {
      guard let file1Node = relativeTree.children.first(where:
              { $0.value.path == TestFileName.file1 } )
      else {
        XCTFail("file1 missing")
        return
      }
      
      XCTAssertEqual(file1Node.value.status, DeltaStatus.unmodified)
    }
  }
  
  func testCommitRootAddFile() throws
  {
    guard let headSHA1 = repository.headSHA,
          let commit1 = repository.commit(forSHA: headSHA1)
    else {
      XCTFail("no head commit")
      return
    }

    try execute(in: repository) {
      CommitFiles {
        Write("text", to: .file2)
      }
    }

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

    XCTAssertEqual(tree1.children.count, 1)
    XCTAssertEqual(tree2.children.count, 2)
    checkCommitTrees(deletedPath: nil)
  }
  
  func testCommitRootSubFile() throws
  {
    try execute(in: repository) {
      CommitFiles {
        Write("text", to: .subFile2)
      }
    }

    checkCommitTrees(deletedPath: nil)
  }
  
  func testCommitRootDeleteSubFile() throws
  {
    let subFilePathA = subDirName +/ subFileNameA
    let subFilePathB = subDirName +/ subFileNameB

    try execute(in: repository) {
      CommitFiles {
        Write("text", to: subFilePathA)
      }
      CommitFiles {
        Write("bbbb", to: subFilePathB)
      }
      CommitFiles {
        Delete(subFilePathA)
      }
    }

    checkCommitTrees(deletedPath: subFilePathA)
  }
  
  func testCommitRootDeleteSubSubFile() throws
  {
    let subFilePathA = subDirName +/ subDirName +/ subFileNameA
    let subFilePathB = subDirName +/ subDirName +/ subFileNameB

    try execute(in: repository) {
      CommitFiles {
        Write("text", to: subFilePathA)
      }
      CommitFiles {
        Write("bbb", to: subFilePathB)
      }
      CommitFiles("delete") {
        Delete(subFilePathA)
      }
    }

    checkCommitTrees(deletedPath: subFilePathA)
  }
  
  func testCommitRootDeleteRootFile() throws
  {
    let subFilePathA = subDirName +/ subFileNameA

    try execute(in: repository) {
      CommitFiles() {
        Write("text", to: subFilePathA)
      }
      CommitFiles("delete") {
        Delete(.file1)
      }
    }

    checkCommitTrees(deletedPath: TestFileName.file1.rawValue)
  }
  
  func makeSubFolderCommits() throws -> (any Commit, any Commit)
  {
    let subFilePath = subDirName +/ subFileNameA

    // Add a file to a subfolder, and save the tree from that commit
    try execute(in: repository) {
      CommitFiles {
        Write("text", to: subFilePath)
      }
    }

    let parentCommit = try XCTUnwrap(repository.headSHA.flatMap(
        { repository.commit(forSHA: $0) }))
    
    // Make a new commit where that subfolder is unchanged
    try execute(in: repository) {
      CommitFiles("commit 3") {
        Write("changes", to: .file1)
      }
    }

    let headSHA = try XCTUnwrap(repository.headSHA)
    let commit = try XCTUnwrap(repository.commit(forSHA: headSHA))
    
    return (parentCommit, commit)
  }
  
  // Make sure that when a subtree is copied from an old tree, its statuses
  // are updated.
  func testCommitRootUpdateUnchanged() throws
  {
    let (parentCommit, commit) = try makeSubFolderCommits()
    let subFilePath = subDirName +/ subFileNameA
    
    let parentModel = CommitSelection(repository: repository, commit: parentCommit)
    let parentRoot = parentModel.fileList.treeRoot(oldTree: nil)
    
    // Double check that the file shows up as added
    let newNode = try XCTUnwrap(parentRoot.commitTreeItemNode(forPath: subFilePath))
    let newItem = newNode.value

    XCTAssertEqual(newItem.status, DeltaStatus.added)
    
    let model = CommitSelection(repository: repository, commit: commit)
    let root = model.fileList.treeRoot(oldTree: parentRoot)
    let fileNode = try XCTUnwrap(root.commitTreeItemNode(forPath: subFilePath))
    let item = fileNode.value

    XCTAssertEqual(item.status, DeltaStatus.unmodified)
  }
  
  // Like testCommitRootUpdateUnchanged but going the other way
  func testCommitRootUpdateReversed() throws
  {
    let (parentCommit, commit) = try makeSubFolderCommits()
    let subFilePath = subDirName +/ subFileNameA
    
    let model = CommitSelection(repository: repository, commit: commit)
    let root = model.fileList.treeRoot(oldTree: nil)
    guard let fileNode = root.commitTreeItemNode(forPath: subFilePath)
    else {
      XCTFail("can't get item")
      return
    }
    
    XCTAssertEqual(fileNode.value.status, DeltaStatus.unmodified)

    let parentModel = CommitSelection(repository: repository, commit: parentCommit)
    let parentRoot = parentModel.fileList.treeRoot(oldTree: root)
    
    let newNode = try XCTUnwrap(parentRoot.commitTreeItemNode(forPath: subFilePath))
    let newItem = newNode.value

    XCTAssertEqual(newItem.status, DeltaStatus.added)
  }
}

extension FileChangeNode
{
  func deepEquals(other: FileChangeNode) -> Bool
  {
    return self == other &&
      zip(children, other.children).allSatisfy { $0.deepEquals(other: $1) }
  }

  func commitTreeItemNode(forPath path: String, root: String = "") -> FileChangeNode?
  {
    let relativePath = path.droppingPrefix(root + "/")
    guard let topFolderName = relativePath.firstPathComponent
    else { return nil }
    let folderPath = root.isEmpty ? topFolderName : root +/ topFolderName
    guard let node = children.first(where: { $0.value.path == folderPath })
    else { return nil }
    
    if node.value.path == path {
      return node
    }
    else {
      return node.commitTreeItemNode(forPath: path, root: folderPath)
    }
  }
  
  func printChangeItems()
  {
    print("\(value.path) - \(value.status)")
    for child in children {
      child.printChangeItems()
    }
  }
}
