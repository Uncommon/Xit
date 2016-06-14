import XCTest

class XTFileChangesModelTest: XTTest {
  
  func data(for string: String) -> NSData
  {
    return (string as NSString).dataUsingEncoding(NSUTF8StringEncoding)!
  }
  
  func string(from data: NSData) -> String
  {
    return NSString(data: data, encoding: NSUTF8StringEncoding)! as String
  }
  
  func testCommit()
  {
    let model = XTCommitChanges(
        repository: repository, sha: repository.headSHA)
    let data = model.dataForFile(file1Name, staged: false)
    
    XCTAssertEqual(data, self.data(for:"some text"))
    
    let patch = try! model.diffForFile(file1Name, staged: false)!.generatePatch()
    
    XCTAssertEqual(patch.addedLinesCount, 1)
  }
  
  func checkPatchLines(
      model: XTFileChangesModel, path: String, staged: Bool,
      added: UInt, deleted: UInt)
  {
    let patch = try! model.diffForFile(path, staged: staged)!.generatePatch()
    
    XCTAssertEqual(patch.addedLinesCount, added,
        String(format: "%@%@", staged ? ">" : "<", path))
    XCTAssertEqual(patch.deletedLinesCount, deleted,
        String(format: "%@%@", staged ? ">" : "<", path))
  }
  
  func testStash() {
    self.makeStash()
    
    let model = XTStashChanges(repository: repository, index: 0)
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
}
