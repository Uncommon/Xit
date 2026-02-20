import XCTest
@testable import Xit

class XTStashTest: XTTest
{
  func testBinaryDiff() throws
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
    
    if let unstagedDiffResult = selection.fileList.diffForFile(imageName.rawValue) {
      XCTAssertEqual(unstagedDiffResult, .binary)
    }
    else {
      XCTFail("no unstaged diff")
    }
  }
}
