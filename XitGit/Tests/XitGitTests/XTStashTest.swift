import XCTest
@testable import XitGit

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
  
  func testChanges() throws
  {
    try makeStash()
    
    let repoPath = self.repoPath as NSString
    let addedPath = repoPath.appendingPathComponent(TestFileName.added.rawValue)
    let untrackedPath = repoPath.appendingPathComponent(TestFileName.untracked.rawValue)
    
    // Stash should have cleaned up both new files
    XCTAssertFalse(FileManager.default.fileExists(atPath: untrackedPath))
    XCTAssertFalse(FileManager.default.fileExists(atPath: addedPath))
    
    let stash = GitStash(repo: repository, index: 0, message: "stash 0")
    let indexChanges = stash.indexChanges()
    let workspaceChanges = stash.workspaceChanges()
    
    guard indexChanges.count == 1,
          workspaceChanges.count == 2
    else {
      XCTFail("wrong file count")
      return
    }
    
    XCTAssertEqual(indexChanges[0].path, TestFileName.added.rawValue)
    XCTAssertEqual(indexChanges[0].status, DeltaStatus.added)
    XCTAssertEqual(workspaceChanges[0].path, TestFileName.file1.rawValue)
    XCTAssertEqual(workspaceChanges[0].status, DeltaStatus.modified)
    XCTAssertEqual(workspaceChanges[1].path, TestFileName.untracked.rawValue)
    XCTAssertEqual(workspaceChanges[1].status, DeltaStatus.added)
    
    XCTAssertNotNil(stash.headBlobForPath(TestFileName.file1.rawValue))
    
    let changeDiffResult = try XCTUnwrap(stash.unstagedDiffForFile(TestFileName.file1.rawValue))
    let changeDiffMaker = try XCTUnwrap(checkDiffResult(changeDiffResult))
    let changePatch = try XCTUnwrap(changeDiffMaker.makePatch())
    
    XCTAssertEqual(changePatch.addedLinesCount, 1)
    XCTAssertEqual(changePatch.deletedLinesCount, 1)
    
    let untrackedDiffResult = try XCTUnwrap(stash.unstagedDiffForFile(TestFileName.untracked.rawValue))
    let untrackedDiffMaker = try XCTUnwrap(checkDiffResult(untrackedDiffResult))
    let untrackedPatch = try XCTUnwrap(untrackedDiffMaker.makePatch())
    
    XCTAssertEqual(untrackedPatch.addedLinesCount, 1)
    XCTAssertEqual(untrackedPatch.deletedLinesCount, 0)
    
    let addedDiffResult = try XCTUnwrap(stash.stagedDiffForFile(TestFileName.added.rawValue))
    let addedDiffMaker = try XCTUnwrap(checkDiffResult(addedDiffResult))
    let addedPatch = try XCTUnwrap(addedDiffMaker.makePatch())
    
    XCTAssertEqual(addedPatch.addedLinesCount, 1)
    XCTAssertEqual(addedPatch.deletedLinesCount, 0)
  }
  
  func testBinaryDiff() throws
  {
    let imageName = TestFileName.tiff

    try execute(in: repository) {
      MakeTiffFile(imageName)
      Stage(imageName)
      SaveStash()
    }

    let stash = GitStash(repo: repository, index: 0, message: "stash 0")
    
    if let stagedDiffResult = stash.stagedDiffForFile(imageName.rawValue) {
      XCTAssertEqual(stagedDiffResult, .binary)
    }
    else {
      XCTFail("no staged diff")
    }
    
    if let unstagedDiffResult = stash.unstagedDiffForFile(imageName.rawValue) {
      XCTAssertEqual(unstagedDiffResult, .binary)
    }
    else {
      XCTFail("no unstaged diff")
    }
  }

  func testSelectionBinaryDiff() throws
  {
    let imageName = TestFileName.tiff

    try execute(in: repository) {
      MakeTiffFile(imageName)
      Stage(imageName)
      SaveStash()
    }

    let selection = StashSelection(repository: repository, index: 0)
    
    if let stagedDiffResult = selection.fileList.diffForFile(imageName.rawValue) {
      XCTAssertEqual(stagedDiffResult, .binary)
    }
    else {
      XCTFail("no staged diff")
    }
    
    if let unstagedDiffResult = selection.unstagedFileList.diffForFile(imageName.rawValue) {
      XCTAssertEqual(unstagedDiffResult, .binary)
    }
    else {
      XCTFail("no unstaged diff")
    }
  }
}
