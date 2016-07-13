import XCTest

class XTStashTest: XTTest
{

  func testChanges()
  {
    self.makeStash()
    
    let addedPath =
      (self.repoPath as NSString).stringByAppendingPathComponent(addedName)
    let untrackedPath =
        (self.repoPath as NSString).stringByAppendingPathComponent(untrackedName)
    let addedIndex = 0, file1Index = 1, untrackedIndex = 2;
    
    // Stash should have cleaned up both new files
    XCTAssertFalse(NSFileManager.defaultManager().fileExistsAtPath(untrackedPath))
    XCTAssertFalse(NSFileManager.defaultManager().fileExistsAtPath(addedPath))
    
    let stash = XTStash(repo: self.repository, index: 0, message: "stash 0")
    let changes = stash.changes()
    let addedChange: XTFileChange = changes[addedIndex]
    let file1Change: XTFileChange = changes[file1Index]
    let untrackedChange: XTFileChange = changes[untrackedIndex]
    
    XCTAssertEqual(changes.count, 3)
    XCTAssertEqual(addedChange.path, addedName)
    XCTAssertEqual(addedChange.change, XitChange.Added)
    XCTAssertEqual(addedChange.unstagedChange, XitChange.Unmodified)
    XCTAssertEqual(file1Change.path, self.file1Name)
    XCTAssertEqual(file1Change.change, XitChange.Unmodified)
    XCTAssertEqual(file1Change.unstagedChange, XitChange.Modified)
    XCTAssertEqual(untrackedChange.path, untrackedName)
    XCTAssertEqual(untrackedChange.change, XitChange.Unmodified)
    XCTAssertEqual(untrackedChange.unstagedChange, XitChange.Added)
    
    XCTAssertNotNil(stash.headBlobForPath(self.file1Name))
    
    let changeDiff = stash.unstagedDiffForFile(self.file1Name)
    let changePatch = try! changeDiff!.generatePatch()
    
    XCTAssertEqual(changePatch.addedLinesCount, 1)
    XCTAssertEqual(changePatch.deletedLinesCount, 1)
    
    let untrackedDiff = stash.unstagedDiffForFile(untrackedName)
    let untrackedPatch = try! untrackedDiff!.generatePatch()
    
    XCTAssertEqual(untrackedPatch.addedLinesCount, 1)
    XCTAssertEqual(untrackedPatch.deletedLinesCount, 0)
    
    let addedDiff = stash.stagedDiffForFile(addedName)
    let addedPatch = try! addedDiff!.generatePatch()
    
    XCTAssertEqual(addedPatch.addedLinesCount, 1)
    XCTAssertEqual(addedPatch.deletedLinesCount, 0)
  }

}
