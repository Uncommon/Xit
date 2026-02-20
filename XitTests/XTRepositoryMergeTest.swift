import XCTest
@testable import Xit
import XitGit

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

    let contents = try XCTUnwrap(String(contentsOf: repository.fileURL(fileName),
                                        encoding: .utf8))

    XCTAssertEqual(contents, result15)
    assertWorkspaceContent(staged: [], unstaged: [])
  }
  
}
