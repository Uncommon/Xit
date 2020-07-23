import XCTest
@testable import Xit

extension Sequence where Self.Iterator.Element == String
{
  func toLines() -> String
  {
    return self.joined(separator: "\n")
  }
}

extension Array
{
  func replacing(_ newElement: Element, at index: Int) -> Array
  {
    var newArray = self
    
    newArray[index] = newElement
    return newArray
  }
}

// Based on the t7600-merge test from git
class XTRepositoryMergeTest: XTTest
{
  let fileName = "file"
  let numbers: [String] = Array(1...9).map { "\($0)" }
  var text1, text5, text9, text9y: String!
  var result1, result15, result159, result9z: String!
  
  func add(_ file: String) throws
  {
    try repository.stage(file: file)
  }
  
  func commit(_ message: String) throws
  {
    try repository.commit(message: message, amend: false)
  }
  
  func branch(_ name: String)
  {
    XCTAssertTrue(repository.createBranch(name))
  }
  
  override func addInitialRepoContent() throws
  {
    text1 = numbers.replacing("1 X", at: 0).toLines()
    text5 = numbers.replacing("5 X", at: 4).toLines()
    text9 = numbers.replacing("9 X", at: 8).toLines()
    text9y = numbers.replacing("9 Y", at: 8).toLines()
  
    result1   = text1
    result15  = numbers.replacing("1 X", at: 0)
                       .replacing("5 X", at: 4).toLines()
    result159 = numbers.replacing("1 X", at: 0)
                       .replacing("5 X", at: 4)
                       .replacing("9 X", at: 8).toLines()
    result9z  = numbers.replacing("9 Z", at: 8).toLines()
    
    write(text:numbers.toLines(), to:fileName)
    
    try add(fileName)
    try commit("commit 0")
    branch("c0")
    branch("c1")
    write(text:text1, to:fileName)
    try add(fileName)
    try commit("commit 1")
    try repository.checkOut(branch: "c0")
    branch("c2")
    write(text:text5, to:fileName)
    try add(fileName)
    try commit("commit 2")
    try repository.checkOut(branch: "c0")
    /* From the git test, not currently used
    branch("c7")
    writeText(text9y, toFile: fileName)
    try add(fileName)
    try commit("commit 7")
    try repository.checkout("c0")
    */
    branch("c3")
    write(text:text9, to: fileName)
    try add(fileName)
    try commit("commit 3")
    try repository.checkOut(branch: "c0")
  }
  
  func isWorkspaceClean() -> Bool
  {
    let selection = StagingSelection(repository: repository)
    
    return selection.fileList.changes.isEmpty &&
           selection.unstagedFileList.changes.isEmpty
  }
  
  func assertWorkspaceContent(staged: [String], unstaged: [String],
                              file: StaticString = #file, line: UInt = #line)
  {
    let selection = StagingSelection(repository: repository)
    
    XCTAssertEqual(selection.fileList.changes.map { $0.path }, staged,
                   "staged", file: file, line: line)
    XCTAssertEqual(selection.unstagedFileList.changes.map { $0.path }, unstaged,
                   "unstaged", file: file, line: line)
  }
  
  // Fast-forward case. This could also have a ff-only variant.
  func testMergeC0C1() throws
  {
    let c1 = try XCTUnwrap(GitLocalBranch(repository: repository.gitRepo, name: "c1",
                                          config: repository.config))

    try self.repository.merge(branch: c1)
    XCTAssertEqual(try String(contentsOf: repository.fileURL(fileName)), result1)
    assertWorkspaceContent(staged: [], unstaged: [])
  }
  
  // Actually merging changes.
  func testMergeC1C2() throws
  {
    let c2 = try XCTUnwrap(GitLocalBranch(repository: repository.gitRepo, name: "c2",
                                          config: repository.config))
    
    try repository.checkOut(branch: "c1")
    try self.repository.merge(branch: c2)
    
    let contents = try XCTUnwrap(String(contentsOf: repository.fileURL(fileName)))
    
    XCTAssertEqual(contents, result15)
    assertWorkspaceContent(staged: [], unstaged: [])
  }
  
  // Not from the git test.
  func testConflict() throws
  {
    write(text: text9y, to: fileName)
    try add(fileName)
    try commit("commit y")
    
    let c3 = GitLocalBranch(repository: repository.gitRepo, name: "c3",
                            config: repository.config)!
    
    do {
      try self.repository.merge(branch: c3)
      XCTFail("No conflict detected")
    }
    catch RepoError.conflict {
      let index = try XCTUnwrap(repository.index, "missing index")
      
      XCTAssertTrue(index.hasConflicts)
      
      let expectedConflicts = [fileName]
      let oursConflicts = index.conflicts.map { $0.ours.path }
      let theirsConflicts = index.conflicts.map { $0.theirs.path }

      XCTAssertEqual(oursConflicts, expectedConflicts)
      XCTAssertEqual(theirsConflicts, expectedConflicts)

      XCTAssertTrue(
          FileManager.default.fileExists(atPath: repository.mergeHeadPath))
    }
  }
  
  func testDirtyFFNoConflict() throws
  {
    let content = "blah"
    let c3 = try XCTUnwrap(repository.localBranch(named: "c3"), "c3 branch missing")
    
    try repository.checkOut(branch: "c0")
    write(text: content, to: FileName.file2)
    try repository.merge(branch: c3)
    assertContent(content, file: FileName.file2)
  }
  
  // Same as testDirtyFFNoConflict except make a commit after switching to c0
  // so it's not a fast forward merge
  func testDirtyNoConflict() throws
  {
    let content = "blah"
    let c3 = try XCTUnwrap(repository.localBranch(named: "c3"), "c3 branch missing")
    
    try repository.checkOut(branch: "c0")
    commit(newTextFile: FileName.added, content: "other")
    write(text: content, to: FileName.file2)
    try repository.merge(branch: c3)
    assertContent(content, file: FileName.file2)
  }
  
  // Further test cases:
  // - dirty worktree/index
  // - merge in progress
}
