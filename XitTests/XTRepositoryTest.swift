import XCTest
@testable import Xit

extension Xit.PatchMaker.PatchResult
{
  func extractPatch() -> Patch?
  {
    switch self {
      case .diff(let maker):
        return maker.makePatch()
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
  
  func testIsTextFileName()
  {
    let textFiles = ["COPYING", "a.txt", "a.c", "a.xml", "a.html"]
    let nonTextFiles = ["a.jpg", "a.png", "a.ffff", "AAAAA"]
    
    for name in textFiles {
      XCTAssertTrue(repository.isTextFile(name, context: .workspace),
                    "\(name) should be a text file")
    }
    for name in nonTextFiles {
      XCTAssertFalse(repository.isTextFile(name, context: .workspace),
                     "\(name) should not be a text file")
    }
  }
  
  func testWorkspaceTextFile()
  {
    let textName = "text"
    
    write(text: "some text", to: textName)
    XCTAssertTrue(repository.isTextFile(textName, context: .workspace))
  }
  
  func testWorkspaceBinaryFile()
  {
    let tiffName = "action"
    
    XCTAssertNoThrow(try makeTiffFile(tiffName))
    XCTAssertFalse(repository.isTextFile(tiffName, context: .workspace))
  }
  
  func testIndexTextFile()
  {
    let textName = "text"
    
    write(text: "some text", to: textName)
    XCTAssertNoThrow(try repository.stage(file: textName))
    XCTAssertTrue(repository.isTextFile(textName, context: .index))
  }
  
  func testIndexBinaryFile()
  {
    let tiffName = "action"
    
    XCTAssertNoThrow(try makeTiffFile(tiffName))
    XCTAssertNoThrow(try repository.stage(file: tiffName))
    XCTAssertFalse(repository.isTextFile(tiffName, context: .index))
  }
  
  func testCommitTextFile()
  {
    let textName = "text"
    
    write(text: "some text", to: textName)
    XCTAssertNoThrow(try repository.stage(file: textName))
    XCTAssertNoThrow(try repository.commit(message: "text", amend: false,
                                           outputBlock: nil))
    
    guard let headSHA = repository.headSHA,
          let headCommit = repository.commit(forSHA: headSHA)
    else {
      XCTFail("no head")
      return
    }

    XCTAssertTrue(repository.isTextFile(textName, context: .commit(headCommit)))
  }
  
  func testCommitBinaryFile()
  {
    let tiffName = "action"

    XCTAssertNoThrow(try makeTiffFile(tiffName))
    XCTAssertNoThrow(try repository.stage(file: tiffName))
    XCTAssertNoThrow(try repository.commit(message: "text", amend: false,
                                           outputBlock: nil))
    
    guard let headSHA = repository.headSHA,
          let headCommit = repository.commit(forSHA: headSHA)
    else {
      XCTFail("no head")
      return
    }

    XCTAssertFalse(repository.isTextFile(tiffName, context: .commit(headCommit)))
  }
  
  func testStagedContents()
  {
    let content = "some content"
    
    writeTextToFile1(content)
    XCTAssertNil(repository.contentsOfStagedFile(path: FileName.file1))
    try! repository.stage(file: FileName.file1)
    
    let expectedContent = content.data(using: .utf8)
    guard let stagedContent = repository.contentsOfStagedFile(path: FileName.file1)
    else {
      XCTFail("can't get staged content of \(FileName.file1)")
      return
    }
    let stagedString = String(data: stagedContent, encoding: .utf8)
    
    XCTAssertEqual(stagedContent, expectedContent)
    XCTAssertEqual(stagedString, content)
    
    // Write to the workspace file, but don't stage it. The staged content
    // should be the same.
    let newContent = "new stuff"
    
    writeTextToFile1(newContent)
    
    let stagedContent2 = repository.contentsOfStagedFile(path: FileName.file1)!
    let stagedString2 = String(data: stagedContent, encoding: .utf8)
    
    XCTAssertEqual(stagedContent2, expectedContent)
    XCTAssertEqual(stagedString2, content)
  }
}

class XTAmendTest: XTTest
{
  // TODO: Move this up to XTTest
  struct FileNames
  {
    static let file1 = "file1"
    static let file2 = "file2"
    static let file3 = "file3"
    static let file4 = "file4"
  }

  override func addInitialRepoContent()
  {
    write(text: "text", to: FileNames.file1)
    write(text: "text", to: FileNames.file2)
    XCTAssertNoThrow(try repository.stageAllFiles())
    XCTAssertNoThrow(try repository.commit(message: "commit 1", amend: false,
                                           outputBlock: nil))
  }
  
  func addSecondCommit()
  {
    write(text: "more", to: FileNames.file1)
    try! FileManager.default.removeItem(at: repository.fileURL(FileNames.file2))
    write(text: "more", to: FileNames.file3)
    XCTAssertNoThrow(try repository.stageAllFiles())
    XCTAssertNoThrow(try repository.commit(message: "commit 2", amend: false,
                                           outputBlock: nil))
  }

  // Check amend status where the head commit is the first one
  func testCleanAmendStatusRoot()
  {
    let normalStatus = repository.stagingChanges
    let amendStatus = repository.amendingChanges(parent: nil)

    XCTAssertEqual(normalStatus.count, 0)
    XCTAssertEqual(amendStatus.count, 2)
  }
  
  // Check amend status with no changes relative to the last commit
  func testCleanAmendStatus()
  {
    let headCommit = repository.commit(forSHA: repository.headSHA!)!
    
    addSecondCommit()
    
    let normalStatus = repository.stagingChanges
    let amendStatus = repository.amendingChanges(parent: headCommit)
    
    XCTAssertEqual(normalStatus.count, 0)
    XCTAssertEqual(amendStatus.count, 3)
  }
  
  // Modify a file added in the last commit, then check the amend status
  func testAmendModifyAdded()
  {
    let headCommit = repository.commit(forSHA: repository.headSHA!)!
    
    addSecondCommit()
    write(text: "third", to: FileNames.file3)
    
    let amendStatus = repository.amendingChanges(parent: headCommit)
    guard let file3Status = amendStatus.first(
        where: { $0.path == FileNames.file3 })
    else {
      XCTFail("file 3 status missing")
      return
    }

    XCTAssertEqual(amendStatus.count, 3)
    XCTAssertEqual(file3Status.change, DeltaStatus.added)
  }
  
  // Delete a file added in the last commit, then check the amend status
  func testAmendDeleteAdded()
  {
    let headCommit = repository.commit(forSHA: repository.headSHA!)!
    
    addSecondCommit()
    try! FileManager.default.removeItem(at: repository.fileURL(FileNames.file3))
    
    let amendStatus = repository.amendingChanges(parent: headCommit)
    guard let file3Status = amendStatus.first(
        where: { $0.path == FileNames.file3 })
    else {
      XCTFail("file 3 status missing")
      return
    }
    
    XCTAssertEqual(amendStatus.count, 3)
    XCTAssertEqual(file3Status.change, DeltaStatus.added)
  }
  
  // Test amend status for a file added in the head commit
  func testAddedInHead()
  {
    let headCommit = repository.commit(forSHA: repository.headSHA!)!
    
    addSecondCommit()
    XCTAssertNoThrow(try repository.amendUnstage(file: FileNames.file3))
    
    let amendStatus = repository.amendingChanges(parent: headCommit)
    guard let file3Status = amendStatus.first(where: { $0.path ==
                                                       FileNames.file3 })
    else {
      XCTFail("file 3 status missing")
      return
    }
    
    XCTAssertEqual(file3Status.change, DeltaStatus.unmodified)
  }
  
  // Test amend status for a file deleted in the head commit
  func testUnstageDeleted()
  {
    let headCommit = repository.commit(forSHA: repository.headSHA!)!
    
    addSecondCommit()
    XCTAssertNoThrow(try repository.amendUnstage(file: FileNames.file2))
    
    let amendStatus = repository.amendingChanges(parent: headCommit)
    guard let file2Status = amendStatus.first(where: { $0.path ==
                                                       FileNames.file2 })
    else {
      XCTFail("file 2 status missing")
      return
    }
    
    XCTAssertEqual(file2Status.change, DeltaStatus.unmodified)
  }
  
  // Stage & unstage a new file in amend mode
  func testAddedNew()
  {
    let headCommit = repository.commit(forSHA: repository.headSHA!)!
    let fileName = FileNames.file4
    let match = { (change: FileStagingChange) in change.path == fileName }
    
    addSecondCommit()
    write(text: "text", to: fileName)
    
    var amendStatus = repository.amendingChanges(parent: headCommit)
    guard let file4Status1 = amendStatus.first(where: match)
    else {
      XCTFail("file 4 status missing")
      return
    }
    
    XCTAssertEqual(file4Status1.change, DeltaStatus.unmodified)
    
    XCTAssertNoThrow(try repository.amendStage(file: fileName))
    amendStatus = repository.amendingChanges(parent: headCommit)
    
    guard let file4Status2 = amendStatus.first(where: match)
    else {
      XCTFail("file 4 status missing")
      return
    }
    
    XCTAssertEqual(file4Status2.change, DeltaStatus.added)
    
    XCTAssertNoThrow(try repository.amendUnstage(file: fileName))
    amendStatus = repository.amendingChanges(parent: headCommit)
    
    guard let file4Status3 = amendStatus.first(where: match)
    else {
      XCTFail("file 4 status missing")
      return
    }
    
    XCTAssertEqual(file4Status3.change, DeltaStatus.unmodified)
  }
  
  // Stage & unstage a newly deleted file in amend mode
  func testDeletedNew()
  {
    let headCommit = repository.commit(forSHA: repository.headSHA!)!
    let fileName = FileNames.file1
    let match = { (change: FileStagingChange) in change.path == fileName }
    
    addSecondCommit()
    try! FileManager.default.removeItem(at: repository.fileURL(fileName))
    
    var amendStatus = repository.amendingChanges(parent: headCommit)
    
    if let fileStatus = amendStatus.first(where: match) {
      // It shows up as modified in the index because file1 was changed
      // in the second commit.
      XCTAssertEqual(fileStatus.change, DeltaStatus.modified)
    }
    else {
      XCTFail("file status missing")
      return
    }
    
    XCTAssertNoThrow(try repository.amendStage(file: fileName))
    amendStatus = repository.amendingChanges(parent: headCommit)
    if let fileStatus = amendStatus.first(where: match) {
      XCTAssertEqual(fileStatus.change, DeltaStatus.deleted)
    }
    else {
      XCTFail("file status missing")
      return
    }
    
    XCTAssertNoThrow(try repository.amendUnstage(file: fileName))
    amendStatus = repository.amendingChanges(parent: headCommit)
    if let fileStatus = amendStatus.first(where: match) {
      XCTAssertEqual(fileStatus.change, DeltaStatus.unmodified)
    }
    else {
      XCTFail("file status missing")
      return
    }
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
    writeTextToFile1("modification")
    
    assertWriteException(name: "stageFile") {
      try repository.stage(file: FileName.file1)
    }
    assertWriteException(name: "unstageFile") {
      try repository.unstage(file: FileName.file1)
    }
  }
  
  func testWriteLockStash()
  {
    writeTextToFile1("modification")

    assertWriteException(name: "unstageFile") {
      try repository.saveStash(name: "stashname",
                               keepIndex: false,
                               includeUntracked: false,
                               includeIgnored: true)
    }
    assertWriteException(name: "apply") { try repository.applyStash(index: 0) }
    assertWriteException(name: "drop") { try repository.dropStash(index: 0) }
    writeTextToFile1("modification")
    try! repository.saveStash(name: "stashname",
                              keepIndex: false,
                              includeUntracked: false,
                              includeIgnored: true)
    assertWriteException(name: "pop") { try repository.popStash(index: 0) }
  }
  
  func testWriteLockCommit()
  {
    writeTextToFile1("modification")
    try! repository.stage(file: FileName.file1)
    
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
      try repository.checkOut(branch: masterBranch)
    }
    assertWriteBool(name: "delete") {
      repository.deleteBranch(testBranch2)
    }
  }
  
  func testWriteLockTags()
  {
    guard let headOID = repository.headSHA.flatMap({ repository.oid(forSHA: $0) })
    else {
      XCTFail("no head")
      return
    }
    
    assertWriteException(name: "create") {
      try repository.createTag(name: "tag", targetOID: headOID, message: "msg")
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
    try! repository.stage(file: FileName.file1)
    try! repository.checkOut(sha: firstSHA)
    
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
          let headCommit = GitCommit(sha: headSHA,
                                     repository: repository.gitRepo)
    else {
        XCTFail("no head SHA")
        return
    }
    let contentData = repository.contentsOfFile(path: FileName.file1,
                                                at: headCommit)!
    let contentString = String(data: contentData, encoding: .utf8)
    
    XCTAssertEqual(contentString, "some text")
  }
  
  func testFileBlob()
  {
    guard let blob = repository.fileBlob(ref: "HEAD", path: FileName.file1)
    else {
      XCTFail("no blob")
      return
    }
    
    var blobString: String? = nil
    
    XCTAssertNoThrow(
        try blob.withData({ blobString = String(data: $0, encoding: .utf8) }))
    XCTAssertEqual(blobString, "some text")
  }
  
  func testAddedChange()
  {
    let changes = repository.changes(for: repository.headSHA!, parent: nil)
    
    XCTAssertEqual(changes.count, 1)
    
    guard let change = changes.first
    else { return }
    
    XCTAssertEqual(change.path, FileName.file1)
    XCTAssertEqual(change.change, DeltaStatus.added)
  }
  
  func testModifiedChange()
  {
    let file2Path = repoPath.appending(pathComponent: FileName.file2)
    
    writeTextToFile1("changes!")
    try! "new file 2".write(toFile: file2Path, atomically: true, encoding: .utf8)
    try! repository.stage(file: FileName.file1)
    try! repository.stage(file: FileName.file2)
    try! repository.commit(message: "#2", amend: false, outputBlock: nil)
    
    let changes2 = repository.changes(for: repository.headSHA!, parent: nil)
    
    XCTAssertEqual(changes2.count, 2)
    
    guard let file1Change = changes2.first
    else { return }
    
    XCTAssertEqual(file1Change.path, FileName.file1)
    XCTAssertEqual(file1Change.change, .modified)
    
    let file2Change = changes2[1]
    
    XCTAssertEqual(file2Change.path, FileName.file2)
    XCTAssertEqual(file2Change.change, .added)
  }
  
  func testDeletedChange()
  {
    try! FileManager.default.removeItem(atPath: file1Path)
    try! repository.stage(file: FileName.file1)
    try! repository.commit(message: "#3", amend: false, outputBlock: nil)
    
    let changes3 = repository.changes(for: repository.headSHA!, parent: nil)
    
    XCTAssertEqual(changes3.count, 1)
    
    guard let file1Deleted = changes3.first
    else { return }
    
    XCTAssertEqual(file1Deleted.path, FileName.file1)
    XCTAssertEqual(file1Deleted.change, .deleted)
  }
  
  func testStageUnstageAllStatus()
  {
    commit(newTextFile: FileName.file2, content: "blah")
    
    let file2Path = repoPath.appending(pathComponent: FileName.file2)
    
    write(text: "blah", to: FileName.file1)
    XCTAssertNoThrow(try FileManager.default.removeItem(atPath: file2Path))
    write(text: "blah", to: FileName.file3)
    XCTAssertNoThrow(try repository.stageAllFiles())
    
    var changes = repository.statusChanges(.indexOnly)
    
    XCTAssertEqual(changes.count, 3);
    XCTAssertEqual(changes[0].change, DeltaStatus.modified);
    XCTAssertEqual(changes[1].change, DeltaStatus.deleted);
    XCTAssertEqual(changes[2].change, DeltaStatus.added);
    
    try! repository.unstageAllFiles()
    changes = repository.statusChanges(.workdirOnly)
    
    XCTAssertEqual(changes.count, 3);
    XCTAssertEqual(changes[0].change, DeltaStatus.modified);
    XCTAssertEqual(changes[1].change, DeltaStatus.deleted);
    XCTAssertEqual(changes[2].change, DeltaStatus.untracked);
  }

  func checkDeletedDiff(_ diffResult: PatchMaker.PatchResult?)
  {
    guard let diffResult = diffResult
    else {
      XCTFail("no diff")
      return
    }
    
    var makerPatch: Patch? = nil
    
    switch diffResult {
      case .diff(let maker):
        makerPatch = maker.makePatch()
      default:
        XCTFail("wrong kind of diff")
        return
    }
    
    guard let patch = makerPatch
    else {
      XCTFail("patch is null")
      return
    }
    
    XCTAssertEqual(patch.hunkCount, 1, "hunks")
    XCTAssertEqual(patch.addedLinesCount, 0, "added lines")
    XCTAssertEqual(patch.deletedLinesCount, 1, "deleted lines")
    for hunkIndex in 0..<patch.hunkCount {
      guard let hunk = patch.hunk(at: hunkIndex)
      else {
        XCTFail("can't get hunk \(hunkIndex)")
        continue
      }
      
      hunk.enumerateLines {
        (line) in
        switch line.type {
          case .deletion:
            XCTAssertEqual(line.text, "some text")
          default:
            break
        }
      }
    }
  }
  
  func testUnstagedDeleteDiff()
  {
    XCTAssertNoThrow(try FileManager.default.removeItem(atPath: file1Path))
    checkDeletedDiff(repository.unstagedDiff(file: FileName.file1))
  }

  func testStagedDeleteDiff()
  {
    XCTAssertNoThrow(try FileManager.default.removeItem(atPath: file1Path))
    XCTAssertNoThrow(try repository.stage(file: FileName.file1))
    checkDeletedDiff(repository.stagedDiff(file: FileName.file1))
  }
  
  func testDeletedDiff()
  {
    try! FileManager.default.removeItem(atPath: file1Path)
    try! repository.stage(file: FileName.file1)
    try! repository.commit(message: "deleted", amend: false,
                           outputBlock: nil)
    
    guard let commit = GitCommit(ref: "HEAD", repository: repository.gitRepo)
    else {
      XCTFail("no HEAD")
      return
    }
    
    let parentOID = commit.parentOIDs.first!
    let diffResult = repository.diffMaker(forFile: FileName.file1,
                                          commitOID: commit.oid,
                                          parentOID: parentOID)!
    let patch = diffResult.extractPatch()!
    
    XCTAssertEqual(patch.deletedLinesCount, 1)
  }
  
  func testAddedDiff()
  {
    guard let commit = GitCommit(ref: "HEAD", repository: repository.gitRepo)
    else {
      XCTFail("no HEAD")
      return
    }
    
    let diffResult = repository.diffMaker(forFile: FileName.file1,
                                          commitOID: commit.oid,
                                          parentOID: nil)!
    let patch = diffResult.extractPatch()!
    
    XCTAssertEqual(patch.addedLinesCount, 1)
  }
  
  func testStagedBinaryDiff()
  {
    let imageName = "img.tiff"
    
    XCTAssertNoThrow(try makeTiffFile(imageName))
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
    let imageName = "img.tiff"
    
    XCTAssertNoThrow(try makeTiffFile(imageName))
    XCTAssertNoThrow(try repository.stage(file: imageName))
    XCTAssertNoThrow(try repository.commit(message: "image", amend: false,
                                           outputBlock: nil))
    
    guard let headCommit = repository.commit(forSHA: repository.headSHA!)
    else {
      XCTFail("no head commit")
      return
    }
    
    let model = CommitSelection(repository: repository, commit: headCommit)
    guard let diff = model.fileList.diffForFile(imageName)
    else {
      XCTFail("no diff result")
      return
    }
    
    XCTAssertEqual(diff, .binary)
  }
}

extension PatchMaker.PatchResult: Equatable
{
  public static func ==(lhs: PatchMaker.PatchResult, rhs: PatchMaker.PatchResult) -> Bool
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
          let patch = diffResult.extractPatch()
    else {
      XCTFail()
      return
    }
    let hunk = patch.hunk(at: 0)!
    
    XCTAssertNoThrow(try repository.patchIndexFile(path: loremName, hunk: hunk,
                                                   stage: true))
    
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
          let patch = diffResult.extractPatch(),
          let hunk = patch.hunk(at: 0)
    else {
      XCTFail()
      return
    }
    
    XCTAssertNoThrow(try repository.patchIndexFile(path: loremName, hunk: hunk,
                                                   stage: false))
    
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
          let patch = diffResult.extractPatch(),
          let hunk = patch.hunk(at: 0)
    else {
      XCTFail()
      return
    }

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

    guard let diffResult = repository.unstagedDiff(file: FileName.file1),
          let patch = diffResult.extractPatch(),
          let hunk = patch.hunk(at: 0)
    else {
      XCTFail()
      return
    }
    
    try! repository.patchIndexFile(path: FileName.file1, hunk: hunk, stage: true)
    
    let status = try! repository.status(file: FileName.file1)
    
    XCTAssertEqual(status.0, DeltaStatus.unmodified)
    XCTAssertEqual(status.1, DeltaStatus.deleted)
  }
  
  /// Tests unstaging a new file as a hunk
  func testUnstageNewHunk()
  {
    try! FileManager.default.copyItem(at: loremURL, to: loremRepoURL)
    try! repository.stage(file: loremName)
    
    guard let diffResult = repository.stagedDiff(file: loremName),
          let patch = diffResult.extractPatch(),
          let hunk = patch.hunk(at: 0)
    else {
      XCTFail()
      return
    }
    
    try! repository.patchIndexFile(path: loremName, hunk: hunk, stage: false)
    
    let status = try! repository.status(file: loremName)
    
    XCTAssertEqual(status.0, DeltaStatus.untracked)
    XCTAssertEqual(status.1, DeltaStatus.unmodified) // There is no "absent"
  }
  
  /// Tests unstaging a deleted file as a hunk
  func testUnstageDeletedHunk()
  {
    try! FileManager.default.removeItem(atPath: file1Path)
    try! repository.stage(file: FileName.file1)
    
    guard let diffResult = repository.stagedDiff(file: FileName.file1),
          let patch = diffResult.extractPatch(),
          let hunk = patch.hunk(at: 0)
    else {
      XCTFail()
      return
    }
    
    try! repository.patchIndexFile(path: FileName.file1, hunk: hunk, stage: false)
    
    let status = try! repository.status(file: FileName.file1)
    
    XCTAssertEqual(status.0, DeltaStatus.deleted)
    XCTAssertEqual(status.1, DeltaStatus.unmodified)
  }
}
