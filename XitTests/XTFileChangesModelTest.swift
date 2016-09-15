import XCTest
@testable import Xit

class XTFileChangesModelTest: XTTest {
  
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
    guard let headSHA = repository.headSHA
    else {
      XCTFail("no head")
      return
    }
    let model = XTCommitChanges(
        repository: repository, sha: headSHA)
    let changes = model.changes
    
    XCTAssertEqual(changes.count, 1)
    
    let change = changes[0]
    
    XCTAssertEqual(change.path, file1Name)
    XCTAssertEqual(change.change, XitChange.Added)
    
    let data = model.dataForFile(file1Name, staged: false)
    
    XCTAssertEqual(data, self.data(for:"some text"))
    
    let patch = try! model.diffForFile(file1Name, staged: false)!.generatePatch()
    
    XCTAssertEqual(patch.addedLinesCount, 1)
  }
  
  func checkPatchLines(
      _ model: XTFileChangesModel, path: String, staged: Bool,
      added: UInt, deleted: UInt)
  {
    let patch = try! model.diffForFile(path, staged: staged)!.generatePatch()
    
    XCTAssertEqual(patch.addedLinesCount, added,
        String(format: "%@%@", staged ? ">" : "<", path))
    XCTAssertEqual(patch.deletedLinesCount, deleted,
        String(format: "%@%@", staged ? ">" : "<", path))
  }
  
  func testStash()
  {
    self.makeStash()
    
    let model = XTStashChanges(repository: repository, index: 0)
    
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
    let model = XTStagingChanges(repository: repository)
    var changes = model.changes
    
    XCTAssertEqual(changes.count, 0)
    
    self.writeText(toFile1: "change")
    changes = model.changes
    XCTAssertEqual(changes.count, 1)
    
    var change = changes[0]
    
    XCTAssertEqual(change.path, file1Name)
    XCTAssertEqual(change.unstagedChange, XitChange.Modified)
    
    self.writeText("new", toFile: addedName)
    changes = model.changes
    XCTAssertEqual(changes.count, 2)
    change = changes[0] // "added" will be sorted to the top
    XCTAssertEqual(change.path, addedName)
    XCTAssertEqual(change.unstagedChange, XitChange.Untracked)
    
    try! repository.stageFile(addedName)
    changes = model.changes
    XCTAssertEqual(changes.count, 2)
    change = changes[0]
    XCTAssertEqual(change.path, addedName)
    XCTAssertEqual(change.change, XitChange.Added)
    XCTAssertEqual(change.unstagedChange, XitChange.Unmodified)
  }
  
  func testStagingTreeSimple()
  {
    let model = XTStagingChanges(repository: repository)
    let tree = model.treeRoot
    
    XCTAssertNotNil(tree.childNodes)
    XCTAssertEqual(tree.childNodes!.count, 1)
    
    let change = tree.childNodes![0].representedObject!
    
    XCTAssertEqual(change.change, XitChange.Unmodified)
  }
  
  func testCommitTree()
  {
    self.commitNewTextFile(addedName, content: "new")
    
    guard let headSHA = repository.headSHA
      else {
        XCTFail("no head")
        return
    }
    let model = XTCommitChanges(repository: repository,
                                sha: headSHA)
    let tree = model.treeRoot
    
    XCTAssertNotNil(tree.childNodes)
    XCTAssertEqual(tree.childNodes!.count, 2)
    
    var change = tree.childNodes![0].representedObject!
    
    XCTAssertEqual(change.path, addedName)
    XCTAssertEqual(change.change, XitChange.Added)
    
    change = tree.childNodes![1].representedObject!
    XCTAssertEqual(change.path, file1Name)
    XCTAssertEqual(change.change, XitChange.Unmodified)
  }
  
  func testStashTree()
  {
    let deletedName = "deleted"
    let deletedURL = repository.repoURL.appendingPathComponent(deletedName)
  
    self.commitNewTextFile(deletedName, content: "bye!")
    try! FileManager.default.removeItem(at: deletedURL)
    try! self.repository.stageFile(deletedName)
    
    self.makeStash()
    
    let model = XTStashChanges(repository: repository, index: 0)
    let tree = model.treeRoot
    
    XCTAssertEqual(tree.childNodes!.count, 4)
    
    let expectedPaths =
        [addedName,   deletedName, file1Name,   untrackedName]
    let expectedChanges: [XitChange] =
        [.added,      .deleted,    .unmodified, .unmodified]
    let expectedUnstaged: [XitChange] =
        [.unmodified, .unmodified, .modified,   .untracked]
    
    for i in 0...3 {
      let item = tree.childNodes![i].representedObject as! XTFileChange
      
      XCTAssertEqual(item.path, expectedPaths[i])
      XCTAssertEqual(item.change, expectedChanges[i],
          "\(item.path) change: \(item.change.rawValue)")
      XCTAssertEqual(item.unstagedChange, expectedUnstaged[i],
          "\(item.path) unstaged: \(item.unstagedChange.rawValue)")
    }
  }
}
