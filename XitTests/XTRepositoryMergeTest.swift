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
    let selection = StagingSelection(repository: repository, amending: false)
    
    return selection.fileList.changes.isEmpty &&
           selection.unstagedFileList.changes.isEmpty
  }
  
  func assertWorkspaceContent(staged: [String], unstaged: [String],
                              file: StaticString = #file, line: UInt = #line)
  {
    let selection = StagingSelection(repository: repository, amending: false)
    
    XCTAssertEqual(selection.fileList.changes.map { $0.path }, staged,
                   "staged", file: file, line: line)
    XCTAssertEqual(selection.unstagedFileList.changes.map { $0.path }, unstaged,
                   "unstaged", file: file, line: line)
  }

  func mergeC0C1(useCLI: Bool) throws
  {
    guard let c1OID = repository.localBranch(named: .init("c1")!)?.oid
    else {
      XCTFail("c1 branch missing")
      return
    }

    if useCLI {
      _ = try repository.executeGit(args: ["merge", "c1"], writes: true)
    }
    else {
      try execute(in: repository) {
        Merge(branch: "c1")
      }
    }
    assertContent(result1, file: fileName)
    try assertStagedContent(result1, file: fileName)
    assertWorkspaceContent(staged: [], unstaged: [])

    guard let headOID = repository.headReference?.targetOID
    else {
      XCTFail("no head")
      return
    }

    XCTAssertTrue(c1OID == headOID)
  }
  
  // Fast-forward case. This could also have a ff-only variant.
  func testMergeC0C1() throws
  {
    try mergeC0C1(useCLI: false)
  }

  func testMergeC0C1CLI() throws
  {
    try mergeC0C1(useCLI: true)
  }

  // Actually merging changes.
  func testMergeC1C2() throws
  {
    try execute(in: repository) {
      CheckOut(branch: "c1")
      Merge(branch: "c2")
    }

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

    do {
      try execute(in: repository) {
        Merge(branch: "c3")
      }
      XCTFail("No conflict detected")
    }
    catch RepoError.conflict {
      let index = try XCTUnwrap(repository.index as? GitIndex, "missing index")
      
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

  /// Merge with an untracked file
  func testDirtyFFNoConflict() throws
  {
    let content = "blah"
    let file = TestFileName.file2

    try execute(in: repository) {
      CheckOut(branch: "c0")
      Write(content, to: file)
      Merge(branch: "c3")
    }
    assertContent(content, file: file)
  }

  /// Merge with a new staged file
  func testDirtyFFStagedNew() throws
  {
    let content = "blah"
    let file = TestFileName.file2

    try XCTContext.runActivity(named: "Set up for merge") {
      _ in
      try execute(in: repository) {
        CheckOut(branch: "c0")
        Write(content, to: file)
        Stage(file)
      }
      assertContent(content, file: file)
      try assertStagedContent(content, file: file)
    }

    try XCTContext.runActivity(named: "Perform merge") {
      _ in
      try execute(in: repository) {
        Merge(branch: "c3")
      }
      assertContent(content, file: file)
      try assertStagedContent(content, file: file)
    }
  }

  /// Merge with a new staged file using command line
  func testDirtyFFStagedNewCLI() throws
  {
    let content = "blah"
    let file = TestFileName.file2

    try XCTContext.runActivity(named: "Set up for merge") {
      _ in
      try execute(in: repository) {
        CheckOut(branch: "c0")
        Write(content, to: file)
        Stage(file)
      }
      assertContent(content, file: file)
      try assertStagedContent(content, file: file)
    }

    try XCTContext.runActivity(named: "Perform merge") {
      _ in
      _ = try repository.executeGit(args: ["merge", "c3"], writes: true)
      assertContent(content, file: file)
      try assertStagedContent(content, file: file)
    }
  }

  /// Merge with staged changes that do not conflict
  func testDirtyFFStagedModified() throws
  {
    let content = "blah"
    let file = TestFileName.file3

    try execute(in: repository) {
      CheckOut(branch: "c0")
      CommitFiles {
        Write(content, to: file)
      }
      Stage(file)
      Merge(branch: "c3")
    }
    assertContent(content, file: file)
    try assertStagedContent(content, file: file)
  }

  // Same as testDirtyFFNoConflict except make a commit after switching to c0
  // so it's not a fast forward merge
  func testDirtyNoConflict() throws
  {
    let content = "blah"

    try execute(in: repository) {
      CheckOut(branch: "c0")
      CommitFiles {
        Write("other", to: .added)
      }
      Write(content, to: .file2)
      Merge(branch: "c3")
    }

    assertContent(content, file: .file2)
  }
  
  // Further test cases:
  // - dirty worktree/index
  // - merge in progress
}
