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
    XCTAssertNoThrow(try repository.commit(message: message, amend: false, outputBlock: nil))
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
    
    writeText(numbers.toLines(), toFile: fileName)
    
    add(fileName)
    commit("commit 0")
    branch("c0")
    branch("c1")
    writeText(text1, toFile: fileName)
    add(fileName)
    commit("commit 1")
    XCTAssertNoThrow(try repository.checkout(branch: "c0"))
    branch("c2")
    writeText(text5, toFile: fileName)
    add(fileName)
    commit("commit 2")
    XCTAssertNoThrow(try repository.checkout(branch: "c0"))
    /* From the git test, not currently used
    branch("c7")
    writeText(text9y, toFile: fileName)
    add(fileName)
    commit("commit 7")
    XCTAssertNoThrow(try repository.checkout("c0"))
    */
    branch("c3")
    writeText(text9, toFile: fileName)
    add(fileName)
    commit("commit 3")
    XCTAssertNoThrow(try repository.checkout(branch: "c0"))
  }
  
  func isWorkspaceClean() -> Bool
  {
    let selection = StagingSelection(repository: repository)
    
    return selection.fileList.changes.isEmpty &&
           selection.unstagedFileList.changes.isEmpty
  }
  
  // Fast-forward case. This could also have a ff-only variant.
  func testMergeC0C1()
  {
    guard let c1 = GitLocalBranch(repository: repository, name: "c1")
    else {
      XCTFail("can't get branch")
      return
    }

    XCTAssertNoThrow(try self.repository.merge(branch: c1))
    XCTAssertEqual(try! String(contentsOf: repository.fileURL(fileName)), result1)
    XCTAssertTrue(isWorkspaceClean())
  }
  
  // Actually merging changes.
  func testMergeC1C2()
  {
    guard let c2 = GitLocalBranch(repository: repository, name: "c2")
    else {
      XCTFail("can't get branch")
      return
    }
    
    XCTAssertNoThrow(try repository.checkout(branch: "c1"))
    XCTAssertNoThrow(try self.repository.merge(branch: c2))
    XCTAssertEqual(try! String(contentsOf: repository.fileURL(fileName)), result15)
    XCTAssertTrue(isWorkspaceClean())
  }
  
  // Not from the git test.
  func testConflict()
  {
    writeText(text9y, toFile: fileName)
    add(fileName)
    commit("commit y")
    
    let c3 = GitLocalBranch(repository: repository, name: "c3")!
    
    do {
      try self.repository.merge(branch: c3)
      XCTFail("No conflict detected")
    }
    catch XTRepository.Error.conflict {
      let index = try! repository.gtRepo.index()
      var conflicts = [String]()
      
      XCTAssertTrue(index.hasConflicts)
      try! index.enumerateConflictedFiles {
        (_, ours, _, _) in
        conflicts.append(ours.path)
      }
      XCTAssertEqual(conflicts, [fileName])
      
      XCTAssertTrue(
          FileManager.default.fileExists(atPath: repository.mergeHeadPath))
    }
    catch {
      XCTFail("Unexpected error thrown")
    }
  }
  
  // Further test cases:
  // - dirty worktree/index
  // - merge in progress
}
