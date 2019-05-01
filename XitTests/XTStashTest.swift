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
    XCTAssertNoThrow(try self.makeStash())
    
    let repoPath = self.repoPath as NSString
    let addedPath = repoPath.appendingPathComponent(FileName.added)
    let untrackedPath = repoPath.appendingPathComponent(FileName.untracked)
    
    // Stash should have cleaned up both new files
    XCTAssertFalse(FileManager.default.fileExists(atPath: untrackedPath))
    XCTAssertFalse(FileManager.default.fileExists(atPath: addedPath))
    
    let stash = GitStash(repo: self.repository, index: 0, message: "stash 0")
    let indexChanges = stash.indexChanges()
    let workspaceChanges = stash.workspaceChanges()
    
    guard indexChanges.count == 1,
          workspaceChanges.count == 2
    else {
      XCTFail("wrong file count")
      return
    }
    
    XCTAssertEqual(indexChanges[0].path, FileName.added)
    XCTAssertEqual(indexChanges[0].status, DeltaStatus.added)
    XCTAssertEqual(workspaceChanges[0].path, FileName.file1)
    XCTAssertEqual(workspaceChanges[0].status, DeltaStatus.modified)
    XCTAssertEqual(workspaceChanges[1].path, FileName.untracked)
    XCTAssertEqual(workspaceChanges[1].status, DeltaStatus.added)
    
    XCTAssertNotNil(stash.headBlobForPath(FileName.file1))
    
    guard let changeDiffResult = stash.unstagedDiffForFile(FileName.file1),
          let changeDiffMaker = checkDiffResult(changeDiffResult),
          let changePatch = changeDiffMaker.makePatch()
    else {
      XCTFail("No change diff")
      return
    }
    
    XCTAssertEqual(changePatch.addedLinesCount, 1)
    XCTAssertEqual(changePatch.deletedLinesCount, 1)
    
    guard let untrackedDiffResult = stash.unstagedDiffForFile(FileName.untracked),
          let untrackedDiffMaker = checkDiffResult(untrackedDiffResult),
          let untrackedPatch = untrackedDiffMaker.makePatch()
    else {
      XCTFail("No untracked diff")
      return
    }
    
    XCTAssertEqual(untrackedPatch.addedLinesCount, 1)
    XCTAssertEqual(untrackedPatch.deletedLinesCount, 0)
    
    guard let addedDiffResult = stash.stagedDiffForFile(FileName.added),
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
    XCTAssertNoThrow(try repository.saveStash(name: nil,
                                              keepIndex: false,
                                              includeUntracked: true,
                                              includeIgnored: true))
    
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
