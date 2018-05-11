import XCTest
@testable import Xit

class XTStashTest: XTTest
{
  func checkDiffResult(_ result: PatchMaker.PatchResult?) -> PatchMaker?
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
    
    // Stash should have cleaned up both new files
    XCTAssertFalse(FileManager.default.fileExists(atPath: untrackedPath))
    XCTAssertFalse(FileManager.default.fileExists(atPath: addedPath))
    
    let stash = XTStash(repo: self.repository, index: 0, message: "stash 0")
    let indexChanges = stash.indexChanges()
    let workspaceChanges = stash.workspaceChanges()
    
    guard indexChanges.count == 1,
          workspaceChanges.count == 2
    else {
      XCTFail("wrong file count")
      return
    }
    
    XCTAssertEqual(indexChanges[0].path, addedName)
    XCTAssertEqual(indexChanges[0].change, DeltaStatus.added)
    XCTAssertEqual(workspaceChanges[0].path, file1Name)
    XCTAssertEqual(workspaceChanges[0].change, DeltaStatus.modified)
    XCTAssertEqual(workspaceChanges[1].path, untrackedName)
    XCTAssertEqual(workspaceChanges[1].change, DeltaStatus.added)
    
    XCTAssertNotNil(stash.headBlobForPath(self.file1Name))
    
    guard let changeDiffResult = stash.unstagedDiffForFile(self.file1Name),
          let changeDiffMaker = checkDiffResult(changeDiffResult),
          let changePatch = changeDiffMaker.makePatch()
    else {
      XCTFail("No change diff")
      return
    }
    
    XCTAssertEqual(changePatch.addedLinesCount, 1)
    XCTAssertEqual(changePatch.deletedLinesCount, 1)
    
    guard let untrackedDiffResult = stash.unstagedDiffForFile(self.untrackedName),
          let untrackedDiffMaker = checkDiffResult(untrackedDiffResult),
          let untrackedPatch = untrackedDiffMaker.makePatch()
    else {
      XCTFail("No untracked diff")
      return
    }
    
    XCTAssertEqual(untrackedPatch.addedLinesCount, 1)
    XCTAssertEqual(untrackedPatch.deletedLinesCount, 0)
    
    guard let addedDiffResult = stash.stagedDiffForFile(addedName),
          let addedDiffMaker = checkDiffResult(addedDiffResult),
          let addedPatch = addedDiffMaker.makePatch()
    else {
      XCTFail("No added diff")
      return
    }
    
    XCTAssertEqual(addedPatch.addedLinesCount, 1)
    XCTAssertEqual(addedPatch.deletedLinesCount, 0)
  }
  
  func testBinaryDiff()
  {
    let imageName = "img.tiff"
    
    XCTAssertNoThrow(try makeTiffFile(imageName))
    XCTAssertNoThrow(try repository.stage(file: imageName))
    XCTAssertNoThrow(try repository.saveStash(name: nil, includeUntracked: true))
    
    let selection = StashSelection(repository: repository, index: 0)
    
    if let stagedDiffResult = selection.fileList.diffForFile(imageName) {
      XCTAssertEqual(stagedDiffResult, .binary)
    }
    else {
      XCTFail("no staged diff")
    }
    
    if let unstagedDiffResult = selection.fileList.diffForFile(imageName) {
      XCTAssertEqual(unstagedDiffResult, .binary)
    }
    else {
      XCTFail("no unstaged diff")
    }
  }
}
