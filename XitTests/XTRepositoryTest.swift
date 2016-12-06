import XCTest
@testable import Xit

class XTRepositoryTest: XTTest
{
  func checkDeletedDiff(_ diff: XTDiffDelta?)
  {
    guard let diff = diff
      else {
        XCTFail("diff is null")
        return
    }
    guard let patch = try? diff.generatePatch()
      else {
        XCTFail("patch is null")
        return
    }
    
    XCTAssertEqual(patch.hunkCount, 1)
    XCTAssertEqual(patch.addedLinesCount, 0)
    XCTAssertEqual(patch.deletedLinesCount, 1)
    patch.enumerateHunks {
      (hunk, stop) in
      try! hunk.enumerateLinesInHunk(usingBlock: {
        (line, stop) in
        switch line.origin {
          case .deletion:
            XCTAssertEqual(line.content, "some text")
          default:
            break
        }
      })
    }
  }

  func testDeleteDiff()
  {
    try? FileManager.default.removeItem(atPath: file1Path)
    checkDeletedDiff(repository.unstagedDiff(file: file1Name))
    
    try! repository.stageFile(file1Name)
    checkDeletedDiff(repository.stagedDiff(file: file1Name))
  }
}
