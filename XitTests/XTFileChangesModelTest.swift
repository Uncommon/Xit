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
    let model = CommitChanges(repository: repository, commit: headCommit)
    let changes = model.changes
    
    XCTAssertEqual(changes.count, 1)
    
    let change = changes[0]
    
    XCTAssertEqual(change.path, file1Name)
    XCTAssertEqual(change.change, DeltaStatus.added)
    
    let data = model.dataForFile(file1Name, staged: false)
    
    XCTAssertEqual(data, self.data(for:"some text"))
    
    guard let diffResult = model.diffForFile(file1Name, staged: false),
          let patch = diffResult.extractPatch()
    else {
      XCTFail()
      return
    }
    
    XCTAssertEqual(patch.addedLinesCount, 1)
  }
  
  func checkPatchLines(
      _ model: FileChangesModel, path: String, staged: Bool,
      added: Int, deleted: Int)
  {
    guard let diffResult = model.diffForFile(path, staged: staged),
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
    
    let model = StashChanges(repository: repository, index: 0)
    
    XCTAssertEqual(model.shaToSelect, repository.headSHA)
    
    let changes = model.changes
    
    XCTAssertEqual(changes.count, 3)
    
    let addedContent =
        self.string(from: model.dataForFile(addedName, staged: true)!)
    let untrackedContent =
        self.string(from: model.dataForFile(untrackedName, staged: false)!)
    let file1Unstaged =
        self.string(from: model.dataForFile(file1Name, staged: false)!)
    let file1Staged =
        self.string(from: model.dataForFile(file1Name, staged: true)!)
    
    XCTAssertEqual(addedContent, "add")
    XCTAssertEqual(untrackedContent, "new")
    XCTAssertEqual(file1Unstaged, "stashy")
    XCTAssertEqual(file1Staged, "some text")
    XCTAssertNil(model.dataForFile(untrackedName, staged: true))
    
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
    XCTAssertNil(model.diffForFile(untrackedName, staged: true))
  }
  
  func testStaging()
  {
    let model = StagingChanges(repository: repository)
    var changes = model.changes
    
    XCTAssertEqual(changes.count, 0)
    
    self.writeText(toFile1: "change")
    changes = model.changes
    XCTAssertEqual(changes.count, 1)
    
    var change = changes[0]
    
    XCTAssertEqual(change.path, file1Name)
    XCTAssertEqual(change.unstagedChange, DeltaStatus.modified)
    
    self.writeText("new", toFile: addedName)
    changes = model.changes
    XCTAssertEqual(changes.count, 2)
    change = changes[0] // "added" will be sorted to the top
    XCTAssertEqual(change.path, addedName)
    XCTAssertEqual(change.unstagedChange, DeltaStatus.untracked)
    
    try! repository.stage(file: addedName)
    changes = model.changes
    XCTAssertEqual(changes.count, 2)
    change = changes[0]
    XCTAssertEqual(change.path, addedName)
    XCTAssertEqual(change.change, DeltaStatus.added)
    XCTAssertEqual(change.unstagedChange, DeltaStatus.unmodified)
  }
  
  func testStagingTreeSimple()
  {
    let model = StagingChanges(repository: repository)
    let tree = model.treeRoot(oldTree: nil)
    
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
    let model = CommitChanges(repository: repository,
                              commit: headCommit)
    let tree = model.treeRoot(oldTree: nil)
    
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
    
    let model = StashChanges(repository: repository, index: 0)
    let tree = model.treeRoot(oldTree: nil)
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
}
