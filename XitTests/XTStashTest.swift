import XCTest
@testable import Xit

class XTStashTest: XTTest
{
  func checkDiffResult(_ result: XTDiffMaker.DiffResult?) -> XTDiffMaker?
  {
    guard let result = result else { return nil }
    
    switch result {
      case .diff(let maker):
        return maker
      default:
        return nil
    }
  }
  
  func testChanges()
  {
    self.makeStash()
    
    let repoPath = self.repoPath as NSString
    let addedPath = repoPath.appendingPathComponent(addedName)
    let untrackedPath = repoPath.appendingPathComponent(untrackedName)
    let addedIndex = 0, file1Index = 1, untrackedIndex = 2;
    
    // Stash should have cleaned up both new files
    XCTAssertFalse(FileManager.default.fileExists(atPath: untrackedPath))
    XCTAssertFalse(FileManager.default.fileExists(atPath: addedPath))
    
    let stash = XTStash(repo: self.repository, index: 0, message: "stash 0")
    let changes = stash.changes()
    let addedChange: FileChange = changes[addedIndex]
    let file1Change: FileChange = changes[file1Index]
    let untrackedChange: FileChange = changes[untrackedIndex]
    
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
    
    guard let changeDiffResult = stash.unstagedDiffForFile(self.file1Name),
          let changeDiffMaker = checkDiffResult(changeDiffResult)
    else {
      XCTFail("No change diff")
      return
    }
    let changeDiff = changeDiffMaker.makeDiff()
    let changePatch = try! changeDiff!.generatePatch()
    
    XCTAssertEqual(changePatch.addedLinesCount, 1)
    XCTAssertEqual(changePatch.deletedLinesCount, 1)
    
    guard let untrackedDiffResult = stash.unstagedDiffForFile(self.untrackedName),
          let untrackedDiffMaker = checkDiffResult(untrackedDiffResult)
    else {
      XCTFail("No untracked diff")
      return
    }
    let untrackedDiff = untrackedDiffMaker.makeDiff()
    let untrackedPatch = try! untrackedDiff!.generatePatch()
    
    XCTAssertEqual(untrackedPatch.addedLinesCount, 1)
    XCTAssertEqual(untrackedPatch.deletedLinesCount, 0)
    
    guard let addedDiffResult = stash.stagedDiffForFile(addedName),
          let addedDiffMaker = checkDiffResult(addedDiffResult)
    else {
      XCTFail("No added diff")
      return
    }
    let addedDiff = addedDiffMaker.makeDiff()
    let addedPatch = try! addedDiff!.generatePatch()
    
    XCTAssertEqual(addedPatch.addedLinesCount, 1)
    XCTAssertEqual(addedPatch.deletedLinesCount, 0)
  }
  
  func testBinaryDiff()
  {
    let imageName = "img.png"
    let imagePath = repoPath.appending(pathComponent: "img.png")
    
    FileManager.default.createFile(atPath: imagePath, contents: nil,
                                   attributes: nil)
    XCTAssertNoThrow(try repository.stage(file: imageName))
    XCTAssertNoThrow(try repository.saveStash(name: nil, includeUntracked: true))
    
    let stashModel = StashChanges(repository: repository, index: 0)
    
    if let stagedDiffResult = stashModel.diffForFile(imageName, staged: true) {
      XCTAssertEqual(stagedDiffResult, .binary)
    }
    else {
      XCTFail("no staged diff")
    }
    
    if let unstagedDiffResult = stashModel.diffForFile(imageName, staged: true) {
      XCTAssertEqual(unstagedDiffResult, .binary)
    }
    else {
      XCTFail("no unstaged diff")
    }
  }
}
