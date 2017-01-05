import XCTest
@testable import Xit

class XTStashTest: XTTest
{

  func testChanges()
  {
    self.makeStash()
    
    let addedPath =
      (self.repoPath as NSString).appendingPathComponent(addedName)
    let untrackedPath =
        (self.repoPath as NSString).appendingPathComponent(untrackedName)
    let addedIndex = 0, file1Index = 1, untrackedIndex = 2;
    
    // Stash should have cleaned up both new files
    XCTAssertFalse(FileManager.default.fileExists(atPath: untrackedPath))
    XCTAssertFalse(FileManager.default.fileExists(atPath: addedPath))
    
    let stash = XTStash(repo: self.repository, index: 0, message: "stash 0")
    let changes = stash.changes()
    let addedChange: XTFileChange = changes[addedIndex]
    let file1Change: XTFileChange = changes[file1Index]
    let untrackedChange: XTFileChange = changes[untrackedIndex]
    
    XCTAssertEqual(changes.count, 3)
    XCTAssertEqual(addedChange.path, addedName)
    XCTAssertEqual(addedChange.change, XitChange.added)
    XCTAssertEqual(addedChange.unstagedChange, XitChange.unmodified)
    XCTAssertEqual(file1Change.path, self.file1Name)
    XCTAssertEqual(file1Change.change, XitChange.unmodified)
    XCTAssertEqual(file1Change.unstagedChange, XitChange.modified)
    XCTAssertEqual(untrackedChange.path, untrackedName)
    XCTAssertEqual(untrackedChange.change, XitChange.unmodified)
    XCTAssertEqual(untrackedChange.unstagedChange, XitChange.added)
    
    XCTAssertNotNil(stash.headBlobForPath(self.file1Name))
    
    let changeDiff = stash.unstagedDiffForFile(self.file1Name)!.makeDiff()
    let changePatch = try! changeDiff!.generatePatch()
    
    XCTAssertEqual(changePatch.addedLinesCount, 1)
    XCTAssertEqual(changePatch.deletedLinesCount, 1)
    
    let untrackedDiff = stash.unstagedDiffForFile(untrackedName)!.makeDiff()
    let untrackedPatch = try! untrackedDiff!.generatePatch()
    
    XCTAssertEqual(untrackedPatch.addedLinesCount, 1)
    XCTAssertEqual(untrackedPatch.deletedLinesCount, 0)
    
    let addedDiff = stash.stagedDiffForFile(addedName)!.makeDiff()
    let addedPatch = try! addedDiff!.generatePatch()
    
    XCTAssertEqual(addedPatch.addedLinesCount, 1)
    XCTAssertEqual(addedPatch.deletedLinesCount, 0)
  }

}
