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
  
  func add(_ file: String)
  {
    XCTAssertNoThrow(try repository.stage(file: file))
  }
  
  func commit(_ message: String)
  {
    XCTAssertNoThrow(try repository.commit(message: message, amend: false))
  }
  
  func branch(_ name: String)
  {
    XCTAssertTrue(repository.createBranch(name))
  }
  
  override func addInitialRepoContent()
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
    
    add(fileName)
    commit("commit 0")
    branch("c0")
    branch("c1")
    write(text:text1, to:fileName)
    add(fileName)
    commit("commit 1")
    XCTAssertNoThrow(try repository.checkOut(branch: "c0"))
    branch("c2")
    write(text:text5, to:fileName)
    add(fileName)
    commit("commit 2")
    XCTAssertNoThrow(try repository.checkOut(branch: "c0"))
    /* From the git test, not currently used
    branch("c7")
    writeText(text9y, toFile: fileName)
    add(fileName)
    commit("commit 7")
    XCTAssertNoThrow(try repository.checkout("c0"))
    */
    branch("c3")
    write(text:text9, to: fileName)
    add(fileName)
    commit("commit 3")
    XCTAssertNoThrow(try repository.checkOut(branch: "c0"))
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
  func testMergeC0C1()
  {
    guard let c1 = GitLocalBranch(repository: repository.gitRepo, name: "c1",
                                  config: repository.config)
    else {
      XCTFail("can't get branch")
      return
    }

    XCTAssertNoThrow(try self.repository.merge(branch: c1))
    XCTAssertEqual(try! String(contentsOf: repository.fileURL(fileName)), result1)
    assertWorkspaceContent(staged: [], unstaged: [])
  }
  
  // Actually merging changes.
  func testMergeC1C2()
  {
    guard let c2 = GitLocalBranch(repository: repository.gitRepo, name: "c2",
                                  config: repository.config)
    else {
      XCTFail("can't get branch")
      return
    }
    
    XCTAssertNoThrow(try repository.checkOut(branch: "c1"))
    XCTAssertNoThrow(try self.repository.merge(branch: c2))
    XCTAssertEqual(try! String(contentsOf: repository.fileURL(fileName)), result15)
    assertWorkspaceContent(staged: [], unstaged: [])
  }
  
  // Not from the git test.
  func testConflict()
  {
    write(text: text9y, to: fileName)
    add(fileName)
    commit("commit y")
    
    let c3 = GitLocalBranch(repository: repository.gitRepo, name: "c3",
                            config: repository.config)!
    
    do {
      try self.repository.merge(branch: c3)
      XCTFail("No conflict detected")
    }
    catch RepoError.conflict {
      guard let index = repository.index
      else {
        XCTFail("missing index")
        return
      }
      
      XCTAssertTrue(index.hasConflicts)
      
      let expectedConflicts = [fileName]
      let oursConflicts = index.conflicts.map { $0.ours.path }
      let theirsConflicts = index.conflicts.map { $0.theirs.path }

      XCTAssertEqual(oursConflicts, expectedConflicts)
      XCTAssertEqual(theirsConflicts, expectedConflicts)

      XCTAssertTrue(
          FileManager.default.fileExists(atPath: repository.mergeHeadPath))
    }
    catch {
      XCTFail("Unexpected error thrown")
    }
  }
  
  func testDirtyFFNoConflict()
  {
    let content = "blah"
    guard let c3 = repository.localBranch(named: "c3")
    else {
      XCTFail("c3 branch missing")
      return
    }
    
    XCTAssertNoThrow(try repository.checkOut(branch: "c0"))
    write(text: content, to: FileName.file2)
    XCTAssertNoThrow(try repository.merge(branch: c3))
    assertContent(content, file: FileName.file2)
  }
  
  // Same as testDirtyFFNoConflict except make a commit after switching to c0
  // so it's not a fast forward merge
  func testDirtyNoConflict()
  {
    let content = "blah"
    guard let c3 = repository.localBranch(named: "c3")
    else {
      XCTFail("c3 branch missing")
      return
    }
    
    XCTAssertNoThrow(try repository.checkOut(branch: "c0"))
    commit(newTextFile: FileName.added, content: "other")
    write(text: content, to: FileName.file2)
    XCTAssertNoThrow(try repository.merge(branch: c3))
    assertContent(content, file: FileName.file2)
  }
  
  // Further test cases:
  // - dirty worktree/index
  // - merge in progress
}
