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
    XCTAssertNoThrow(try repository.commit(message: "text", amend: false))
    
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
    XCTAssertNoThrow(try repository.commit(message: "text", amend: false))
    
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
    XCTAssertNoThrow(try repository.commit(message: "commit 1", amend: false))
  }
  
  func addSecondCommit()
  {
    write(text: "more", to: FileNames.file1)
    try! FileManager.default.removeItem(at: repository.fileURL(FileNames.file2))
    write(text: "more", to: FileNames.file3)
    XCTAssertNoThrow(try repository.stageAllFiles())
    XCTAssertNoThrow(try repository.commit(message: "commit 2", amend: false))
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
    
    let amendChange = repository.amendingChanges(parent: headCommit)
    guard let file3Change = amendChange.first(
        where: { $0.path == FileNames.file3 })
    else {
      XCTFail("file 3 status missing")
      return
    }

    XCTAssertEqual(amendChange.count, 3)
    XCTAssertEqual(file3Change.status, DeltaStatus.added)
  }
  
  // Delete a file added in the last commit, then check the amend status
  func testAmendDeleteAdded()
  {
    let headCommit = repository.commit(forSHA: repository.headSHA!)!
    
    addSecondCommit()
    try! FileManager.default.removeItem(at: repository.fileURL(FileNames.file3))
    
    let amendStatus = repository.amendingChanges(parent: headCommit)
    guard let file3Change = amendStatus.first(
        where: { $0.path == FileNames.file3 })
    else {
      XCTFail("file 3 status missing")
      return
    }
    
    XCTAssertEqual(amendStatus.count, 3)
    XCTAssertEqual(file3Change.status, DeltaStatus.added)
  }
  
  // Test amend status for a file added in the head commit
  func testAddedInHead()
  {
    let headCommit = repository.commit(forSHA: repository.headSHA!)!
    
    addSecondCommit()
    XCTAssertNoThrow(try repository.amendUnstage(file: FileNames.file3))
    
    let amendStatus = repository.amendingChanges(parent: headCommit)
    guard let file3Change = amendStatus.first(where: { $0.path ==
                                                       FileNames.file3 })
    else {
      XCTFail("file 3 status missing")
      return
    }
    
    XCTAssertEqual(file3Change.status, DeltaStatus.unmodified)
  }
  
  // Test amend status for a file deleted in the head commit
  func testUnstageDeleted()
  {
    let headCommit = repository.commit(forSHA: repository.headSHA!)!
    
    addSecondCommit()
    XCTAssertNoThrow(try repository.amendUnstage(file: FileNames.file2))
    
    let amendChange = repository.amendingChanges(parent: headCommit)
    guard let file2Change = amendChange.first(where: { $0.path ==
                                                       FileNames.file2 })
    else {
      XCTFail("file 2 status missing")
      return
    }
    
    XCTAssertEqual(file2Change.status, DeltaStatus.unmodified)
  }
  
  // Stage & unstage a new file in amend mode
  func testAddedNew()
  {
    let headCommit = repository.commit(forSHA: repository.headSHA!)!
    let fileName = FileNames.file4
    let match = { (change: FileStagingChange) in change.path == fileName }
    
    addSecondCommit()
    write(text: "text", to: fileName)
    
    var amendChange = repository.amendingChanges(parent: headCommit)
    guard let file4Change1 = amendChange.first(where: match)
    else {
      XCTFail("file 4 status missing")
      return
    }
    
    XCTAssertEqual(file4Change1.status, DeltaStatus.unmodified)
    
    XCTAssertNoThrow(try repository.amendStage(file: fileName))
    amendChange = repository.amendingChanges(parent: headCommit)
    
    guard let file4Change2 = amendChange.first(where: match)
    else {
      XCTFail("file 4 status missing")
      return
    }
    
    XCTAssertEqual(file4Change2.status, DeltaStatus.added)
    
    XCTAssertNoThrow(try repository.amendUnstage(file: fileName))
    amendChange = repository.amendingChanges(parent: headCommit)
    
    guard let file4Status3 = amendChange.first(where: match)
    else {
      XCTFail("file 4 status missing")
      return
    }
    
    XCTAssertEqual(file4Status3.status, DeltaStatus.unmodified)
  }
  
  // Stage & unstage a newly deleted file in amend mode
  func testDeletedNew()
  {
    let headCommit = repository.commit(forSHA: repository.headSHA!)!
    let fileName = FileNames.file1
    let match = { (change: FileStagingChange) in change.path == fileName }
    
    addSecondCommit()
    try! FileManager.default.removeItem(at: repository.fileURL(fileName))
    
    var amendChange = repository.amendingChanges(parent: headCommit)
    
    if let fileChange = amendChange.first(where: match) {
      // It shows up as modified in the index because file1 was changed
      // in the second commit.
      XCTAssertEqual(fileChange.status, DeltaStatus.modified)
    }
    else {
      XCTFail("file status missing")
      return
    }
    
    XCTAssertNoThrow(try repository.amendStage(file: fileName))
    amendChange = repository.amendingChanges(parent: headCommit)
    if let fileChange = amendChange.first(where: match) {
      XCTAssertEqual(fileChange.status, DeltaStatus.deleted)
    }
    else {
      XCTFail("file status missing")
      return
    }
    
    XCTAssertNoThrow(try repository.amendUnstage(file: fileName))
    amendChange = repository.amendingChanges(parent: headCommit)
    if let fileChange = amendChange.first(where: match) {
      XCTAssertEqual(fileChange.status, DeltaStatus.unmodified)
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
    catch RepoError.alreadyWriting {
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
    catch RepoError.alreadyWriting {
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
      try repository.commit(message: "blah", amend: false)
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
    XCTAssertEqual(change.status, DeltaStatus.added)
  }
  
  func testModifiedChange()
  {
    let file2Path = repoPath.appending(pathComponent: FileName.file2)
    
    writeTextToFile1("changes!")
    try! "new file 2".write(toFile: file2Path, atomically: true, encoding: .utf8)
    try! repository.stage(file: FileName.file1)
    try! repository.stage(file: FileName.file2)
    try! repository.commit(message: "#2", amend: false)
    
    let changes2 = repository.changes(for: repository.headSHA!, parent: nil)
    
    XCTAssertEqual(changes2.count, 2)
    
    guard let file1Change = changes2.first
    else { return }
    
    XCTAssertEqual(file1Change.path, FileName.file1)
    XCTAssertEqual(file1Change.status, .modified)
    
    let file2Change = changes2[1]
    
    XCTAssertEqual(file2Change.path, FileName.file2)
    XCTAssertEqual(file2Change.status, .added)
  }
  
  func testDeletedChange()
  {
    try! FileManager.default.removeItem(atPath: file1Path)
    try! repository.stage(file: FileName.file1)
    try! repository.commit(message: "#3", amend: false)
    
    let changes3 = repository.changes(for: repository.headSHA!, parent: nil)
    
    XCTAssertEqual(changes3.count, 1)
    
    guard let file1Deleted = changes3.first
    else { return }
    
    XCTAssertEqual(file1Deleted.path, FileName.file1)
    XCTAssertEqual(file1Deleted.status, .deleted)
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
    XCTAssertEqual(changes[0].status, DeltaStatus.modified);
    XCTAssertEqual(changes[1].status, DeltaStatus.deleted);
    XCTAssertEqual(changes[2].status, DeltaStatus.added);
    
    try! repository.unstageAllFiles()
    changes = repository.statusChanges(.workdirOnly)
    
    XCTAssertEqual(changes.count, 3);
    XCTAssertEqual(changes[0].status, DeltaStatus.modified);
    XCTAssertEqual(changes[1].status, DeltaStatus.deleted);
    XCTAssertEqual(changes[2].status, DeltaStatus.untracked);
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
    try! repository.commit(message: "deleted", amend: false)
    
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
    XCTAssertNoThrow(try repository.commit(message: "image", amend: false))
    
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
  
  func testTrackingBranch()
  {
    let remoteName = "origin"
    let masterBranchName = "master"
    let remoteBranchName = remoteName +/ masterBranchName
    
    makeRemoteRepo()
    commit(newTextFile: FileName.file1, content: "remote",
           repository: remoteRepository)
    XCTAssertNoThrow(
        try repository.addRemote(named: remoteName,
                                 url: URL(fileURLWithPath: remoteRepoPath)))
    XCTAssertNoThrow(
        try repository.executeGit(args: ["fetch", remoteName],
                                  writes: true))
    XCTAssertNoThrow(
        try repository.executeGit(args: ["branch", "-u", remoteBranchName],
                                  writes: true))
    
    guard let masterBranch = repository.localBranch(named: masterBranchName)
    else {
      XCTFail("master branch missing")
      return
    }
    
    XCTAssertEqual(masterBranch.trackingBranchName, remoteBranchName)
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
