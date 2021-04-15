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

    try execute(in: repository) {
      CommitFiles("commit 0") {
        Write(numbers.toLines(), to: fileName)
      }
      CreateBranch("c0")
      CreateBranch("c1", checkOut: true)
      CommitFiles("commit 1") {
        Write(text1, to: fileName)
      }
      CheckOut(branch: "c0")
      CreateBranch("c2", checkOut: true)
      CommitFiles("commit 2") {
        Write(text5, to: fileName)
      }
      CheckOut(branch: "c0")
      /* From the git test, not currently used
      CreateBranch("c7")
      CommitFiles("commit 7") {
        Write(text9y, to: fileName)
      }
      CheckOut(branch: "c0")
      */
      CreateBranch("c3", checkOut: true)
      CommitFiles("commit 3") {
        Write(text9, to: fileName)
      }
      CheckOut(branch: "c0")
    }
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
    try execute(in: repository) {
      CommitFiles("commit y") {
        Write(text9y, to: fileName)
      }
    }

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

    try execute(in: repository, actions: { () -> [RepoAction] in
      CheckOut(branch: "c0")
      Write(content, to: .file2)
    })
    try repository.merge(branch: c3)
    assertContent(content, file: FileName.file2)
  }

  // Same as testDirtyFFNoConflict except make a commit after switching to c0
  // so it's not a fast forward merge
  func testDirtyNoConflict() throws
  {
    let content = "blah"
    let c3 = try XCTUnwrap(repository.localBranch(named: "c3"), "c3 branch missing")

    try execute(in: repository) {
      CheckOut(branch: "c0")
      CommitFiles {
        Write("other", to: .added)
      }
      Write(content, to: .file2)
    }

    try repository.merge(branch: c3)
    assertContent(content, file: FileName.file2)
  }
  
  // Further test cases:
  // - dirty worktree/index
  // - merge in progress
}
