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
    checkDeletedDiff(repository.unstagedDiff(file: file1Name)!.makeDiff())
    
    try! repository.stageFile(file1Name)
    checkDeletedDiff(repository.stagedDiff(file: file1Name)!.makeDiff())
  }
  
  func testDeletedDiff()
  {
    try! FileManager.default.removeItem(atPath: file1Path)
    try! repository.stageFile(file1Path)
    try! repository.commit(withMessage: "deleted", amend: false,
                           outputBlock: nil)
    
    guard let commit = XTCommit(ref: "HEAD", repository: repository)
    else {
      XCTFail("no HEAD")
      return
    }
    
    let parentSHA = commit.parentSHAs.first!
    let maker = repository.diffMaker(forFile: file1Name,
                                     commitSHA: commit.sha!,
                                     parentSHA: parentSHA)!
    let diff = maker.makeDiff()!
    let patch = try! diff.generatePatch()
    
    XCTAssertEqual(patch.deletedLinesCount, 1)
  }
  
  func testAddedDiff()
  {
    guard let commit = XTCommit(ref: "HEAD", repository: repository)
    else {
      XCTFail("no HEAD")
      return
    }
    
    let maker = repository.diffMaker(forFile: file1Name,
                                     commitSHA: commit.sha!,
                                     parentSHA: nil)!
    let diff = maker.makeDiff()!
    let patch = try! diff.generatePatch()
    
    XCTAssertEqual(patch.addedLinesCount, 1)
  }
}

class XTRepositoryHunkTest: XTTest
{
  let testBundle = Bundle(identifier: "com.uncommonplace.XitTests")!
  let loremName = "lorem.txt"
  var loremURL, lorem2URL: URL!
  var loremRepoURL: URL!

  override func setUp()
  {
    super.setUp()
    loremURL = testBundle.url(forResource: "lorem", withExtension: "txt")!
    lorem2URL = testBundle.url(forResource: "lorem2", withExtension: "txt")!
    loremRepoURL = repository.repoURL.appendingPathComponent(loremName)
  }
  
  /// Returns the content of lorem.txt in the index
  func readLoremIndexText() -> String?
  {
    var encoding = String.Encoding.utf8
    guard let indexData = repository.stagedBlob(file: loremName)?.data()
    else { return nil }
    
    return String(data: indexData, usedEncoding: &encoding)
  }
  
  /// Copies the test bundle's lorem2.txt into the repo's lorem.txt
  func copyLorem2Contents() throws
  {
    let lorem2Data = try! Data(contentsOf: lorem2URL)
    
    try! lorem2Data.write(to: loremRepoURL)
  }
  
  /// Tests staging the first hunk of a changed file
  func testStageHunk()
  {
    try! FileManager.default.copyItem(at: loremURL, to: loremRepoURL)
    try! repository.stageFile(loremName)
    try! copyLorem2Contents()
    
    let diffMaker = repository.unstagedDiff(file: loremName)!
    let diff = diffMaker.makeDiff()!
    let patch = try! diff.generatePatch()
    let hunk = GTDiffHunk(patch: patch, hunkIndex: 0)!
    
    try! repository.patchIndexFile(path: loremName, hunk: hunk, stage: true)
    
    let indexText = readLoremIndexText()!

    XCTAssert(indexText.hasPrefix(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec nec maximus mauris. Quisque varius nisi ac augue rutrum ullamcorper. Sed tincidunt leo in erat commodo, tempor ultricies quam sagittis.\n" +
          "Duis risus quam, malesuada vel ante at, tincidunt sagittis erat. Phasellus a ante erat. Donec tristique lorem leo, sit amet congue est convallis vitae. Vestibulum a faucibus nisl. Pellentesque vitae sem vitae enim pharetra lacinia.\n" +
        "Pellentesque mattis ante eget dignissim cursus. Nullam lacinia sit amet sapien ac feugiat. Aenean sagittis eros dignissim volutpat faucibus. Proin laoreet tempus nunc in suscipit.\n\n"))
  }
  
  /// Tests unstaging the first hunk of a staged file
  func testUnstageHunk()
  {
    try! FileManager.default.copyItem(at: loremURL, to: loremRepoURL)
    try! repository.stageFile(loremName)
    try! repository.commit(withMessage: "lorem", amend: false, outputBlock: nil)
    try! copyLorem2Contents()
    try! repository.stageFile(loremName)
    
    let diffMaker = repository.stagedDiff(file: loremName)!
    let diff = diffMaker.makeDiff()!
    let patch = try! diff.generatePatch()
    let hunk = GTDiffHunk(patch: patch, hunkIndex: 0)!
    
    try! repository.patchIndexFile(path: loremName, hunk: hunk, stage: false)
    
    let indexText = readLoremIndexText()!
    
    XCTAssert(indexText.hasPrefix(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec nec maximus mauris. Quisque varius nisi ac augue rutrum ullamcorper. Sed tincidunt leo in erat commodo, tempor ultricies quam sagittis.\n" +
        "Duis risus quam, malesuada vel ante at, tincidunt sagittis erat. Phasellus a ante erat. Donec tristique lorem leo, sit amet congue est convallis vitae. Vestibulum a faucibus nisl. Pellentesque vitae sem vitae enim pharetra lacinia.\n" +
        "Pellentesque mattis ante eget dignissim cursus. Nullam lacinia sit amet sapien ac feugiat. Aenean sagittis eros dignissim volutpat faucibus. Proin laoreet tempus nunc in suscipit.\n" +
        "Cras vestibulum id neque eu imperdiet. Pellentesque a lacus ipsum. Nulla ultrices consectetur congue.\n"))
  }
  
  /// Tests staging a new file as a hunk
  func testStageNewHunk()
  {
    try! FileManager.default.copyItem(at: loremURL, to: loremRepoURL)
    
    let diffMaker = repository.unstagedDiff(file: loremName)!
    let diff = diffMaker.makeDiff()!
    let patch = try! diff.generatePatch()
    let hunk = GTDiffHunk(patch: patch, hunkIndex: 0)!

    try! repository.patchIndexFile(path: loremName, hunk: hunk, stage: true)
    
    var encoding = String.Encoding.utf8
    let stagedText = readLoremIndexText()!
    let loremData = try! Data(contentsOf: loremURL)
    let loremText = String(data: loremData, usedEncoding: &encoding)!
    
    XCTAssertEqual(stagedText, loremText)
  }
  
  /// Tests staging a deleted file as a hunk
  func testStageDeletedHunk()
  {
    try! FileManager.default.removeItem(atPath: file1Path)

    let diffMaker = repository.unstagedDiff(file: file1Name)!
    let diff = diffMaker.makeDiff()!
    let patch = try! diff.generatePatch()
    let hunk = GTDiffHunk(patch: patch, hunkIndex: 0)!
    
    try! repository.patchIndexFile(path: file1Name, hunk: hunk, stage: true)
    
    let status = try! repository.status(file: file1Name)
    
    XCTAssertEqual(status.0, XitChange.unmodified)
    XCTAssertEqual(status.1, XitChange.deleted)
  }
  
  /// Tests unstaging a new file as a hunk
  func testUnstageNewHunk()
  {
    try! FileManager.default.copyItem(at: loremURL, to: loremRepoURL)
    try! repository.stageFile(loremName)
    
    let diffMaker = repository.stagedDiff(file: loremName)!
    let diff = diffMaker.makeDiff()!
    let patch = try! diff.generatePatch()
    let hunk = GTDiffHunk(patch: patch, hunkIndex: 0)!
    
    try! repository.patchIndexFile(path: loremName, hunk: hunk, stage: false)
    
    let status = try! repository.status(file: loremName)
    
    XCTAssertEqual(status.0, XitChange.untracked)
    XCTAssertEqual(status.1, XitChange.unmodified) // There is no "absent"
  }
  
  /// Tests unstaging a deleted file as a hunk
  func testUnstageDeletedHunk()
  {
    try! FileManager.default.removeItem(atPath: file1Path)
    try! repository.stageFile(file1Name)
    
    let diffMaker = repository.stagedDiff(file: file1Name)!
    let diff = diffMaker.makeDiff()!
    let patch = try! diff.generatePatch()
    let hunk = GTDiffHunk(patch: patch, hunkIndex: 0)!
    
    try! repository.patchIndexFile(path: file1Name, hunk: hunk, stage: false)
    
    let status = try! repository.status(file: file1Name)
    
    XCTAssertEqual(status.0, XitChange.deleted)
    XCTAssertEqual(status.1, XitChange.unmodified)
  }
}
