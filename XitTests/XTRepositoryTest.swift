import XCTest
@testable import Xit

extension Xit.XTDiffMaker.DiffResult
{
  func extractDiff() -> XTDiffDelta?
  {
    switch self {
      case .diff(let maker):
        return maker.makeDiff()
      default:
        return nil
    }
  }
}

class XTEmptyRepositoryTest: XTTest
{
  override func addInitialRepoContent()
  {
  }

  func testEmptyRepositoryHead()
  {
    XCTAssertFalse(repository.hasHeadReference())
    XCTAssertEqual(repository.parentTree(), kEmptyTreeHash)
  }
  
  func testIsTextFile()
  {
    let textFiles = ["COPYING", "a.txt", "a.c", "a.xml", "a.html"]
    let nonTextFiles = ["a.jpg", "a.png", "a.ffff", "AAAAA"]
    
    for name in textFiles {
      XCTAssertTrue(repository.isTextFile(name, commit: "master"),
                    "\(name) should be a text file")
    }
    for name in nonTextFiles {
      XCTAssertFalse(repository.isTextFile(name, commit: "master"),
                     "\(name) should not be a text file")
    }
  }
  
  func testStagedContents()
  {
    let content = "some content"
    
    writeText(toFile1: content)
    XCTAssertNil(repository.contentsOfStagedFile(path: file1Name))
    try! repository.stage(file: file1Name)
    
    let expectedContent = content.data(using: .utf8)
    guard let stagedContent = repository.contentsOfStagedFile(path: file1Name)
    else {
      XCTFail("can't get staged content of \(file1Name)")
      return
    }
    let stagedString = String(data: stagedContent, encoding: .utf8)
    
    XCTAssertEqual(stagedContent, expectedContent)
    XCTAssertEqual(stagedString, content)
    
    // Write to the workspace file, but don't stage it. The staged content
    // should be the same.
    let newContent = "new stuff"
    
    writeText(toFile1: newContent)
    
    let stagedContent2 = repository.contentsOfStagedFile(path: file1Name)!
    let stagedString2 = String(data: stagedContent, encoding: .utf8)
    
    XCTAssertEqual(stagedContent2, expectedContent)
    XCTAssertEqual(stagedString2, content)
  }
}

class XTRepositoryTest: XTTest
{
  func assertWriteSucceeds(name: String, _ block: () throws -> Void)
  {
    do {
      try block()
    }
    catch XTRepository.Error.alreadyWriting {
      XCTFail("\(name): write unexpectedly failed")
    }
    catch {
      XCTFail("\(name): unexpected exception")
    }
  }
  
  func assertWriteFails(name: String, block: () throws -> Void)
  {
    do {
      try block()
      XCTFail("\(name): write unexpectedly succeeded")
    }
    catch XTRepository.Error.alreadyWriting {
    }
    catch {
      XCTFail("\(name): unexpected exception")
    }
  }
  
  func assertWriteException(name: String, block: () throws -> Void)
  {
    setRepoWriting(repository, true)
    assertWriteFails(name: name, block: block)
    setRepoWriting(repository, false)
    assertWriteSucceeds(name: name, block)
  }
  
  func assertWriteBool(name: String, block: () -> Bool)
  {
    setRepoWriting(repository, true)
    XCTAssertFalse(block(), "\(name) writing")
    setRepoWriting(repository, false)
    XCTAssertTrue(block(), "\(name) non-writing")
  }

  func testWriteLockStage()
  {
    writeText(toFile1: "modification")
    
    assertWriteException(name: "stageFile") {
      try repository.stage(file: file1Name)
    }
    assertWriteException(name: "unstageFile") {
      try repository.unstage(file: file1Name)
    }
  }
  
  func testWriteLockStash()
  {
    writeText(toFile1: "modification")

    assertWriteException(name: "unstageFile") {
      try repository.saveStash(name: "stashname", includeUntracked: false)
    }
    assertWriteException(name: "apply") { try repository.applyStash(index: 0) }
    assertWriteException(name: "drop") { try repository.dropStash(index: 0) }
    writeText(toFile1: "modification")
    try! repository.saveStash(name: "stashname", includeUntracked: false)
    assertWriteException(name: "pop") { try repository.popStash(index: 0) }
  }
  
  func testWriteLockCommit()
  {
    writeText(toFile1: "modification")
    try! repository.stage(file: file1Name)
    
    assertWriteException(name: "commit") { 
      try repository.commit(message: "blah", amend: false, outputBlock: nil)
    }
  }
  
  func testWriteLockBranches()
  {
    let masterBranch = "master"
    let testBranch1 = "testBranch1"
    let testBranch2 = "testBranch2"
    
    assertWriteBool(name: "create") { repository.createBranch(testBranch1) }
    assertWriteException(name: "rename") {
      try repository.rename(branch: testBranch1, to: testBranch2)
    }
    assertWriteException(name: "checkout") {
      try repository.checkout(branch: masterBranch)
    }
    assertWriteBool(name: "delete") {
      repository.deleteBranch(testBranch2)
    }
  }
  
  func testWriteLockTags()
  {
    assertWriteException(name: "create") {
      try repository.createTag(name: "tag", targetSHA: repository.headSHA!, message: "msg")
    }
    assertWriteException(name: "delete") {
      try repository.deleteTag(name: "tag")
    }
  }
  
  func testWriteRemotes()
  {
    let testRemoteName1 = "remote1"
    let testRemoteName2 = "remote2"
    
    assertWriteException(name: "add") {
      try repository.addRemote(named: testRemoteName1,
                               url: URL(fileURLWithPath: "fakeurl"))
    }
    assertWriteException(name: "rename") {
      try repository.renameRemote(old: testRemoteName1, new: testRemoteName2)
    }
    assertWriteException(name: "delete") {
      try repository.deleteRemote(named: testRemoteName2)
    }
  }

  func testHeadRef()
  {
    XCTAssertEqual(repository.headRef, "refs/heads/master")
    
    guard let headSHA = repository.headSHA
    else {
      XCTFail("no head SHA")
      return
    }
    let hexChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
    
    XCTAssertEqual(headSHA.utf8.count, 40)
    XCTAssertTrue(headSHA.trimmingCharacters(in: hexChars).isEmpty)
  }
  
  func testDetachedCheckout()
  {
    guard let firstSHA = repository.headSHA
    else {
      XCTFail("no head SHA")
      return
    }
    
    try! "mash".write(toFile: file1Path, atomically: true, encoding: .utf8)
    try! repository.stage(file: file1Name)
    try! repository.checkout(sha: firstSHA)
    
    guard let detachedSHA = repository.headSHA
    else {
      XCTFail("no detached head SHA")
      return
    }
    
    XCTAssertEqual(firstSHA, detachedSHA)
  }
  
  func testContents()
  {
    guard let headSHA = repository.headSHA,
          let headCommit = XTCommit(sha: headSHA, repository: repository)
    else {
        XCTFail("no head SHA")
        return
    }
    let contentData = repository.contentsOfFile(path: file1Name,
                                                at: headCommit)!
    let contentString = String(data: contentData, encoding: .utf8)
    
    XCTAssertEqual(contentString, "some text")
  }
  
  func testAddedChange()
  {
    let changes = repository.changes(for: repository.headSHA!, parent: nil)
    
    XCTAssertEqual(changes.count, 1)
    
    guard let change = changes.first
    else { return }
    
    XCTAssertEqual(change.path, file1Name)
    XCTAssertEqual(change.change, XitChange.added)
  }
  
  func testModifiedChange()
  {
    let file2Name = "file2.txt"
    let file2Path = repoPath.appending(pathComponent: file2Name)
    
    writeText(toFile1: "changes!")
    try! "new file 2".write(toFile: file2Path, atomically: true, encoding: .utf8)
    try! repository.stage(file: file1Name)
    try! repository.stage(file: file2Name)
    try! repository.commit(message: "#2", amend: false, outputBlock: nil)
    
    let changes2 = repository.changes(for: repository.headSHA!, parent: nil)
    
    XCTAssertEqual(changes2.count, 2)
    
    guard let file1Change = changes2.first
    else { return }
    
    XCTAssertEqual(file1Change.path, file1Name)
    XCTAssertEqual(file1Change.change, .modified)
    
    let file2Change = changes2[1]
    
    XCTAssertEqual(file2Change.path, file2Name)
    XCTAssertEqual(file2Change.change, .added)
  }
  
  func testDeletedChange()
  {
    try! FileManager.default.removeItem(atPath: file1Path)
    try! repository.stage(file: file1Name)
    try! repository.commit(message: "#3", amend: false, outputBlock: nil)
    
    let changes3 = repository.changes(for: repository.headSHA!, parent: nil)
    
    XCTAssertEqual(changes3.count, 1)
    
    guard let file1Deleted = changes3.first
    else { return }
    
    XCTAssertEqual(file1Deleted.path, file1Name)
    XCTAssertEqual(file1Deleted.change, .deleted)
  }
  
  func testStageUnstageAllStatus()
  {
    let file2Name = "file2.txt"
    let file3Name = "file3.txt"
    
    commitNewTextFile(file2Name, content: "blah")
    
    let file2Path = repoPath.appending(pathComponent: file2Name)
    let file3Path = repoPath.appending(pathComponent: file3Name)
    
    try! "blah".write(toFile: file1Path, atomically: true, encoding: .utf8)
    try! FileManager.default.removeItem(atPath: file2Path)
    try! "blah".write(toFile: file3Path, atomically: true, encoding: .utf8)
    try! repository.stageAllFiles()
    
    var changes = repository.changes(for: XTStagingSHA, parent: nil)
    
    XCTAssertEqual(changes.count, 3);
    XCTAssertEqual(changes[0].unstagedChange, XitChange.unmodified); // file1
    XCTAssertEqual(changes[0].change, XitChange.modified);
    XCTAssertEqual(changes[1].unstagedChange, XitChange.unmodified); // file2
    XCTAssertEqual(changes[1].change, XitChange.deleted);
    XCTAssertEqual(changes[2].unstagedChange, XitChange.unmodified); // file3
    XCTAssertEqual(changes[2].change, XitChange.added);
    
    try! repository.unstageAllFiles()
    changes = repository.changes(for: XTStagingSHA, parent: nil)
    
    XCTAssertEqual(changes.count, 3);
    XCTAssertEqual(changes[0].unstagedChange, XitChange.modified); // file1
    XCTAssertEqual(changes[0].change, XitChange.unmodified);
    XCTAssertEqual(changes[1].unstagedChange, XitChange.deleted); // file2
    XCTAssertEqual(changes[1].change, XitChange.unmodified);
    XCTAssertEqual(changes[2].unstagedChange, XitChange.untracked); // file3
    XCTAssertEqual(changes[2].change, XitChange.unmodified);
  }

  func checkDeletedDiff(_ diffResult: XTDiffMaker.DiffResult?)
  {
    guard let diffResult = diffResult
    else {
      XCTFail("no diff")
      return
    }
    
    var makerDiff: XTDiffDelta? = nil
    
    switch diffResult {
      case .diff(let maker):
        makerDiff = maker.makeDiff()
      default:
        XCTFail("wrong kind of diff")
        return
    }
    
    guard let diff = makerDiff
    else {
      XCTFail("diff is null")
      return
    }
    guard let patch = try? diff.generatePatch()
    else {
      XCTFail("patch is null")
      return
    }
    
    XCTAssertEqual(patch.hunkCount, 1, "hunks")
    XCTAssertEqual(patch.addedLinesCount, 0, "added lines")
    XCTAssertEqual(patch.deletedLinesCount, 1, "deleted lines")
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
  
  func testUnstagedDeleteDiff()
  {
    XCTAssertNoThrow(try FileManager.default.removeItem(atPath: file1Path))
    checkDeletedDiff(repository.unstagedDiff(file: file1Name))
  }

  func testStagedDeleteDiff()
  {
    XCTAssertNoThrow(try FileManager.default.removeItem(atPath: file1Path))
    XCTAssertNoThrow(try repository.stage(file: file1Name))
    checkDeletedDiff(repository.stagedDiff(file: file1Name))
  }
  
  func testDeletedDiff()
  {
    try! FileManager.default.removeItem(atPath: file1Path)
    try! repository.stage(file: file1Name)
    try! repository.commit(message: "deleted", amend: false,
                           outputBlock: nil)
    
    guard let commit = XTCommit(ref: "HEAD", repository: repository)
    else {
      XCTFail("no HEAD")
      return
    }
    
    let parentOID = commit.parentOIDs.first!
    let diffResult = repository.diffMaker(forFile: file1Name,
                                          commitOID: commit.oid,
                                          parentOID: parentOID)!
    let diff = diffResult.extractDiff()!
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
    
    let diffResult = repository.diffMaker(forFile: file1Name,
                                          commitOID: commit.oid,
                                          parentOID: nil)!
    let diff = diffResult.extractDiff()!
    let patch = try! diff.generatePatch()
    
    XCTAssertEqual(patch.addedLinesCount, 1)
  }
  
  func testStagedBinaryDiff()
  {
    let imageName = "img.png"
    let imagePath = repoPath.appending(pathComponent: "img.png")
    
    FileManager.default.createFile(atPath: imagePath, contents: nil,
                                   attributes: nil)
    XCTAssertNoThrow(try repository.stage(file: imageName))
    
    if let unstagedDiffResult = repository.unstagedDiff(file: imageName) {
      XCTAssertEqual(unstagedDiffResult, .binary)
    }
    else {
      XCTFail("no unstaged diff")
    }
    
    if let stagedDiffResult = repository.stagedDiff(file: imageName) {
      XCTAssertEqual(stagedDiffResult, .binary)
    }
    else {
      XCTFail("no staged diff")
    }
  }
  
  func testCommitBinaryDiff()
  {
    let imageName = "img.png"
    let imagePath = repoPath.appending(pathComponent: "img.png")
    
    FileManager.default.createFile(atPath: imagePath, contents: nil,
                                   attributes: nil)
    XCTAssertNoThrow(try repository.stage(file: imageName))
    XCTAssertNoThrow(try repository.commit(message: "image", amend: false,
                                           outputBlock: nil))
    
    guard let headCommit = repository.commit(forSHA: repository.headSHA!)
    else {
      XCTFail("no head commit")
      return
    }
    
    let model = CommitChanges(repository: repository, commit: headCommit)
    guard let diff = model.diffForFile(imageName, staged: false)
    else {
      XCTFail("no diff result")
      return
    }
    
    XCTAssertEqual(diff, .binary)
  }
}

extension XTDiffMaker.DiffResult: Equatable
{
  public static func ==(lhs: XTDiffMaker.DiffResult, rhs: XTDiffMaker.DiffResult) -> Bool
  {
    switch (lhs, rhs) {
      case (.noDifference, .noDifference),
           (.binary, .binary),
           (.diff(_), .diff(_)):
        return true
      default:
        return false
    }
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
    guard let indexData = repository.stagedBlob(file: loremName)?.makeData()
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
    try! repository.stage(file: loremName)
    try! copyLorem2Contents()
    
    guard let diffResult = repository.unstagedDiff(file: loremName),
          let diff = diffResult.extractDiff()
    else {
      XCTFail()
      return
    }
    let patch = try! diff.generatePatch()
    let hunk = GTDiffHunk(patch: patch, hunkIndex: 0)!
    
    try! repository.patchIndexFile(path: loremName, hunk: hunk, stage: true)
    
    let indexText = readLoremIndexText()!

    XCTAssert(indexText.hasPrefix("""
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec nec maximus mauris. Quisque varius nisi ac augue rutrum ullamcorper. Sed tincidunt leo in erat commodo, tempor ultricies quam sagittis.
        Duis risus quam, malesuada vel ante at, tincidunt sagittis erat. Phasellus a ante erat. Donec tristique lorem leo, sit amet congue est convallis vitae. Vestibulum a faucibus nisl. Pellentesque vitae sem vitae enim pharetra lacinia.
        Pellentesque mattis ante eget dignissim cursus. Nullam lacinia sit amet sapien ac feugiat. Aenean sagittis eros dignissim volutpat faucibus. Proin laoreet tempus nunc in suscipit.

        """))
  }
  
  /// Tests unstaging the first hunk of a staged file
  func testUnstageHunk()
  {
    try! FileManager.default.copyItem(at: loremURL, to: loremRepoURL)
    try! repository.stage(file: loremName)
    try! repository.commit(message: "lorem", amend: false, outputBlock: nil)
    try! copyLorem2Contents()
    try! repository.stage(file: loremName)
    
    guard let diffResult = repository.stagedDiff(file: loremName),
          let diff = diffResult.extractDiff(),
          let patch = try? diff.generatePatch(),
          let hunk = GTDiffHunk(patch: patch, hunkIndex: 0)
    else {
      XCTFail()
      return
    }
    
    try! repository.patchIndexFile(path: loremName, hunk: hunk, stage: false)
    
    let indexText = readLoremIndexText()!
    
    XCTAssert(indexText.hasPrefix("""
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec nec maximus mauris. Quisque varius nisi ac augue rutrum ullamcorper. Sed tincidunt leo in erat commodo, tempor ultricies quam sagittis.
        Duis risus quam, malesuada vel ante at, tincidunt sagittis erat. Phasellus a ante erat. Donec tristique lorem leo, sit amet congue est convallis vitae. Vestibulum a faucibus nisl. Pellentesque vitae sem vitae enim pharetra lacinia.
        Pellentesque mattis ante eget dignissim cursus. Nullam lacinia sit amet sapien ac feugiat. Aenean sagittis eros dignissim volutpat faucibus. Proin laoreet tempus nunc in suscipit.
        Cras vestibulum id neque eu imperdiet. Pellentesque a lacus ipsum. Nulla ultrices consectetur congue.
        """))
  }
  
  /// Tests staging a new file as a hunk
  func testStageNewHunk()
  {
    try! FileManager.default.copyItem(at: loremURL, to: loremRepoURL)
    
    guard let diffResult = repository.unstagedDiff(file: loremName),
          let diff = diffResult.extractDiff()
    else {
      XCTFail()
      return
    }
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

    guard let diffResult = repository.unstagedDiff(file: file1Name),
          let diff = diffResult.extractDiff(),
          let patch = try? diff.generatePatch(),
          let hunk = GTDiffHunk(patch: patch, hunkIndex: 0)
    else {
      XCTFail()
      return
    }
    
    try! repository.patchIndexFile(path: file1Name, hunk: hunk, stage: true)
    
    let status = try! repository.status(file: file1Name)
    
    XCTAssertEqual(status.0, XitChange.unmodified)
    XCTAssertEqual(status.1, XitChange.deleted)
  }
  
  /// Tests unstaging a new file as a hunk
  func testUnstageNewHunk()
  {
    try! FileManager.default.copyItem(at: loremURL, to: loremRepoURL)
    try! repository.stage(file: loremName)
    
    guard let diffResult = repository.stagedDiff(file: loremName),
          let diff = diffResult.extractDiff(),
          let patch = try? diff.generatePatch(),
          let hunk = GTDiffHunk(patch: patch, hunkIndex: 0)
    else {
      XCTFail()
      return
    }
    
    try! repository.patchIndexFile(path: loremName, hunk: hunk, stage: false)
    
    let status = try! repository.status(file: loremName)
    
    XCTAssertEqual(status.0, XitChange.untracked)
    XCTAssertEqual(status.1, XitChange.unmodified) // There is no "absent"
  }
  
  /// Tests unstaging a deleted file as a hunk
  func testUnstageDeletedHunk()
  {
    try! FileManager.default.removeItem(atPath: file1Path)
    try! repository.stage(file: file1Name)
    
    guard let diffResult = repository.stagedDiff(file: file1Name),
          let diff = diffResult.extractDiff(),
          let patch = try? diff.generatePatch(),
          let hunk = GTDiffHunk(patch: patch, hunkIndex: 0)
    else {
      XCTFail()
      return
    }
    
    try! repository.patchIndexFile(path: file1Name, hunk: hunk, stage: false)
    
    let status = try! repository.status(file: file1Name)
    
    XCTAssertEqual(status.0, XitChange.deleted)
    XCTAssertEqual(status.1, XitChange.unmodified)
  }
}
