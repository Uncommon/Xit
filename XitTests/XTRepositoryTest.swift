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
  override func addInitialRepoContent() throws
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
  
  func testWorkspaceBinaryFile() throws
  {
    let tiffName = "action"
    
    try makeTiffFile(tiffName)
    XCTAssertFalse(repository.isTextFile(tiffName, context: .workspace))
  }
  
  func testIndexTextFile() throws
  {
    let textName = "text"
    
    write(text: "some text", to: textName)
    try repository.stage(file: textName)
    XCTAssertTrue(repository.isTextFile(textName, context: .index))
  }
  
  func testIndexBinaryFile() throws
  {
    let tiffName = "action"
    
    try makeTiffFile(tiffName)
    try repository.stage(file: tiffName)
    XCTAssertFalse(repository.isTextFile(tiffName, context: .index))
  }
  
  func testCommitTextFile() throws
  {
    let textName = "text"
    
    write(text: "some text", to: textName)
    try repository.stage(file: textName)
    try repository.commit(message: "text", amend: false)
    
    let headSHA = try XCTUnwrap(repository.headSHA)
    let headCommit = try XCTUnwrap(repository.commit(forSHA: headSHA))

    XCTAssertTrue(repository.isTextFile(textName, context: .commit(headCommit)))
  }
  
  func testCommitBinaryFile() throws
  {
    let tiffName = "action"

    try makeTiffFile(tiffName)
    try repository.stage(file: tiffName)
    try repository.commit(message: "text", amend: false)
    
    let headSHA = try XCTUnwrap(repository.headSHA)
    let headCommit = try XCTUnwrap(repository.commit(forSHA: headSHA))

    XCTAssertFalse(repository.isTextFile(tiffName, context: .commit(headCommit)))
  }
  
  func testStagedContents() throws
  {
    let content = "some content"
    
    writeTextToFile1(content)
    XCTAssertNil(repository.contentsOfStagedFile(path: FileName.file1))
    try repository.stage(file: FileName.file1)
    
    let expectedContent = content.data(using: .utf8)
    let stagedContent = try XCTUnwrap(repository.contentsOfStagedFile(path: FileName.file1))
    let stagedString = String(data: stagedContent, encoding: .utf8)
    
    XCTAssertEqual(stagedContent, expectedContent)
    XCTAssertEqual(stagedString, content)
    
    // Write to the workspace file, but don't stage it. The staged content
    // should be the same.
    let newContent = "new stuff"
    
    writeTextToFile1(newContent)
    
    let stagedContent2 = try XCTUnwrap(repository.contentsOfStagedFile(path: FileName.file1))
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

  override func addInitialRepoContent() throws
  {
    write(text: "text", to: FileNames.file1)
    write(text: "text", to: FileNames.file2)
    try repository.stageAllFiles()
    try repository.commit(message: "commit 1", amend: false)
  }
  
  func addSecondCommit() throws
  {
    write(text: "more", to: FileNames.file1)
    try FileManager.default.removeItem(at: repository.fileURL(FileNames.file2))
    write(text: "more", to: FileNames.file3)
    try repository.stageAllFiles()
    try repository.commit(message: "commit 2", amend: false)
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
  func testCleanAmendStatus() throws
  {
    let headCommit = try XCTUnwrap(repository.commit(forSHA: repository.headSHA!))
    
    try addSecondCommit()
    
    let normalStatus = repository.stagingChanges
    let amendStatus = repository.amendingChanges(parent: headCommit)
    
    XCTAssertEqual(normalStatus.count, 0)
    XCTAssertEqual(amendStatus.count, 3)
  }
  
  // Modify a file added in the last commit, then check the amend status
  func testAmendModifyAdded() throws
  {
    let headCommit = try XCTUnwrap(repository.commit(forSHA: repository.headSHA!))

    try addSecondCommit()
    write(text: "third", to: FileNames.file3)
    
    let amendChange = repository.amendingChanges(parent: headCommit)
    let file3Change = try XCTUnwrap(amendChange.first { $0.path == FileNames.file3 })

    XCTAssertEqual(amendChange.count, 3)
    XCTAssertEqual(file3Change.status, DeltaStatus.added)
  }
  
  // Delete a file added in the last commit, then check the amend status
  func testAmendDeleteAdded() throws
  {
    let headCommit = try XCTUnwrap(repository.commit(forSHA: repository.headSHA!))

    try addSecondCommit()
    try FileManager.default.removeItem(at: repository.fileURL(FileNames.file3))
    
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
  func testAddedInHead() throws
  {
    let headCommit = try XCTUnwrap(repository.commit(forSHA: repository.headSHA!))

    try addSecondCommit()
    try repository.amendUnstage(file: FileNames.file3)
    
    let amendStatus = repository.amendingChanges(parent: headCommit)
    let file3Change = try XCTUnwrap(
          amendStatus.first(where: { $0.path == FileNames.file3 }))
    
    XCTAssertEqual(file3Change.status, DeltaStatus.unmodified)
  }
  
  // Test amend status for a file deleted in the head commit
  func testUnstageDeleted() throws
  {
    let headCommit = try XCTUnwrap(repository.commit(forSHA: repository.headSHA!))

    try addSecondCommit()
    try repository.amendUnstage(file: FileNames.file2)
    
    let amendChange = repository.amendingChanges(parent: headCommit)
    let file2Change = try XCTUnwrap(
          amendChange.first(where: { $0.path == FileNames.file2 }))
    
    XCTAssertEqual(file2Change.status, DeltaStatus.unmodified)
  }
  
  // Stage & unstage a new file in amend mode
  func testAddedNew() throws
  {
    let headCommit = try XCTUnwrap(repository.commit(forSHA: repository.headSHA!))
    let fileName = FileNames.file4
    let match = { (change: FileStagingChange) in change.path == fileName }
    
    try addSecondCommit()
    write(text: "text", to: fileName)
    
    var amendChange = repository.amendingChanges(parent: headCommit)
    let file4Change1 = try XCTUnwrap(amendChange.first(where: match))
    
    XCTAssertEqual(file4Change1.status, DeltaStatus.unmodified)
    
    try repository.amendStage(file: fileName)
    amendChange = repository.amendingChanges(parent: headCommit)
    
    let file4Change2 = try XCTUnwrap(amendChange.first(where: match))
    
    XCTAssertEqual(file4Change2.status, DeltaStatus.added)
    
    try repository.amendUnstage(file: fileName)
    amendChange = repository.amendingChanges(parent: headCommit)
    
    let file4Status3 = try XCTUnwrap(amendChange.first(where: match))
    
    XCTAssertEqual(file4Status3.status, DeltaStatus.unmodified)
  }
  
  // Stage & unstage a newly deleted file in amend mode
  func testDeletedNew() throws
  {
    let headCommit = try XCTUnwrap(repository.commit(forSHA: repository.headSHA!))
    let fileName = FileNames.file1
    let match = { (change: FileStagingChange) in change.path == fileName }
    
    try addSecondCommit()
    try FileManager.default.removeItem(at: repository.fileURL(fileName))
    
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
    
    try repository.amendStage(file: fileName)
    amendChange = repository.amendingChanges(parent: headCommit)
    
    let deletedChange = try XCTUnwrap(amendChange.first(where: match))
    
    XCTAssertEqual(deletedChange.status, DeltaStatus.deleted)
    
    try repository.amendUnstage(file: fileName)
    amendChange = repository.amendingChanges(parent: headCommit)
    
    let unmodifiedChange = try XCTUnwrap(amendChange.first(where: match))
    
    XCTAssertEqual(unmodifiedChange.status, DeltaStatus.unmodified)
  }
}

class XTRepositoryTest: XTTest
{
  func assertWriteSucceeds(name: String,
                           file: StaticString = #file, line: UInt = #line,
                           _ block: () throws -> Void)
  {
    do {
      try block()
    }
    catch RepoError.alreadyWriting {
      XCTFail("\(name): write unexpectedly failed", file: file, line: line)
    }
    catch {
      XCTFail("\(name): unexpected exception", file: file, line: line)
    }
  }
  
  func assertWriteFails(name: String,
                        file: StaticString = #file, line: UInt = #line,
                        block: () throws -> Void)
  {
    do {
      try block()
      XCTFail("\(name): write unexpectedly succeeded", file: file, line: line)
    }
    catch RepoError.alreadyWriting {
    }
    catch {
      XCTFail("\(name): unexpected exception", file: file, line: line)
    }
  }
  
  func assertWriteException(name: String,
                            file: StaticString = #file, line: UInt = #line,
                            block: () throws -> Void)
  {
    setRepoWriting(repository, true)
    assertWriteFails(name: name, file: file, line: line, block: block)
    setRepoWriting(repository, false)
    assertWriteSucceeds(name: name, file: file, line: line, block)
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
  
  func testWriteLockStash() throws
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
    try repository.saveStash(name: "stashname",
                             keepIndex: false,
                             includeUntracked: false,
                             includeIgnored: true)
    assertWriteException(name: "pop") { try repository.popStash(index: 0) }
  }
  
  func testWriteLockCommit() throws
  {
    writeTextToFile1("modification")
    try repository.stage(file: FileName.file1)
    
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
  
  func testContents() throws
  {
    let headSHA = try XCTUnwrap(repository.headSHA)
    let headCommit = try XCTUnwrap(GitCommit(sha: headSHA,
                                             repository: repository.gitRepo))
    let contentData = repository.contentsOfFile(path: FileName.file1,
                                                at: headCommit)!
    let contentString = String(data: contentData, encoding: .utf8)
    
    XCTAssertEqual(contentString, "some text")
  }
  
  func testFileBlob() throws
  {
    let blob = try XCTUnwrap(repository.fileBlob(ref: "HEAD", path: FileName.file1))
    var blobString: String? = nil
    
    try blob.withData({ blobString = String(data: $0, encoding: .utf8) })
    XCTAssertEqual(blobString, "some text")
  }
  
  func testAddedChange() throws
  {
    let changes = repository.changes(for: repository.headSHA!, parent: nil)
    
    XCTAssertEqual(changes.count, 1)
    
    let change = try XCTUnwrap(changes.first)
    
    XCTAssertEqual(change.path, FileName.file1)
    XCTAssertEqual(change.status, DeltaStatus.added)
  }
  
  func testModifiedChange() throws
  {
    let file2Path = repoPath.appending(pathComponent: FileName.file2)
    
    writeTextToFile1("changes!")
    try "new file 2".write(toFile: file2Path, atomically: true, encoding: .utf8)
    try repository.stage(file: FileName.file1)
    try repository.stage(file: FileName.file2)
    try repository.commit(message: "#2", amend: false)
    
    let changes2 = repository.changes(for: repository.headSHA!, parent: nil)
    
    XCTAssertEqual(changes2.count, 2)
    
    let file1Change = try XCTUnwrap(changes2.first)
    
    XCTAssertEqual(file1Change.path, FileName.file1)
    XCTAssertEqual(file1Change.status, .modified)
    
    let file2Change = changes2[1]
    
    XCTAssertEqual(file2Change.path, FileName.file2)
    XCTAssertEqual(file2Change.status, .added)
  }
  
  func testDeletedChange() throws
  {
    try FileManager.default.removeItem(atPath: file1Path)
    try repository.stage(file: FileName.file1)
    try repository.commit(message: "#3", amend: false)
    
    let changes3 = repository.changes(for: repository.headSHA!, parent: nil)
    
    XCTAssertEqual(changes3.count, 1)
    
    let file1Deleted = try XCTUnwrap(changes3.first)
    
    XCTAssertEqual(file1Deleted.path, FileName.file1)
    XCTAssertEqual(file1Deleted.status, .deleted)
  }
  
  func testStageUnstageAllStatus() throws
  {
    commit(newTextFile: FileName.file2, content: "blah")
    
    let file2Path = repoPath.appending(pathComponent: FileName.file2)
    
    write(text: "blah", to: FileName.file1)
    try FileManager.default.removeItem(atPath: file2Path)
    write(text: "blah", to: FileName.file3)
    try repository.stageAllFiles()
    
    var changes = repository.statusChanges(.indexOnly)
    
    XCTAssertEqual(changes.count, 3);
    XCTAssertEqual(changes[0].status, DeltaStatus.modified);
    XCTAssertEqual(changes[1].status, DeltaStatus.deleted);
    XCTAssertEqual(changes[2].status, DeltaStatus.added);
    
    try repository.unstageAllFiles()
    changes = repository.statusChanges(.workdirOnly)
    
    XCTAssertEqual(changes.count, 3);
    XCTAssertEqual(changes[0].status, DeltaStatus.modified);
    XCTAssertEqual(changes[1].status, DeltaStatus.deleted);
    XCTAssertEqual(changes[2].status, DeltaStatus.untracked);
  }

  func checkDeletedDiff(_ diffResult: PatchMaker.PatchResult?,
                        file: StaticString = #file, line: UInt = #line) throws
  {
    let diffResult = try XCTUnwrap(diffResult, file: file, line: line)
    
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
  
  func testUnstagedDeleteDiff() throws
  {
    try FileManager.default.removeItem(atPath: file1Path)
    try checkDeletedDiff(repository.unstagedDiff(file: FileName.file1))
  }

  func testStagedDeleteDiff() throws
  {
    try FileManager.default.removeItem(atPath: file1Path)
    try repository.stage(file: FileName.file1)
    try checkDeletedDiff(repository.stagedDiff(file: FileName.file1))
  }
  
  func testDeletedDiff() throws
  {
    try FileManager.default.removeItem(atPath: file1Path)
    try repository.stage(file: FileName.file1)
    try repository.commit(message: "deleted", amend: false)
    
    let commit = try XCTUnwrap(GitCommit(ref: "HEAD", repository: repository.gitRepo))
    let parentOID = try XCTUnwrap(commit.parentOIDs.first)
    let diffResult = repository.diffMaker(forFile: FileName.file1,
                                          commitOID: commit.oid,
                                          parentOID: parentOID)!
    let patch = try XCTUnwrap(diffResult.extractPatch())
    
    XCTAssertEqual(patch.deletedLinesCount, 1)
  }
  
  func testAddedDiff() throws
  {
    let commit = try XCTUnwrap(GitCommit(ref: "HEAD", repository: repository.gitRepo))
    let diffResult = repository.diffMaker(forFile: FileName.file1,
                                          commitOID: commit.oid,
                                          parentOID: nil)!
    let patch = try XCTUnwrap(diffResult.extractPatch())
    
    XCTAssertEqual(patch.addedLinesCount, 1)
  }
  
  func testStagedBinaryDiff() throws
  {
    let imageName = "img.tiff"
    
    try makeTiffFile(imageName)
    try repository.stage(file: imageName)
    
    let unstagedDiffResult = try XCTUnwrap(repository.unstagedDiff(file: imageName))
    
    XCTAssertEqual(unstagedDiffResult, .binary)
    
    let stagedDiffResult = try XCTUnwrap(repository.stagedDiff(file: imageName))

    XCTAssertEqual(stagedDiffResult, .binary)
  }
  
  func testCommitBinaryDiff() throws
  {
    let imageName = "img.tiff"
    
    try makeTiffFile(imageName)
    try repository.stage(file: imageName)
    try repository.commit(message: "image", amend: false)
    
    let headCommit = try XCTUnwrap(repository.commit(forSHA: repository.headSHA!))
    let model = CommitSelection(repository: repository, commit: headCommit)
    let diff = try XCTUnwrap(model.fileList.diffForFile(imageName))
    
    XCTAssertEqual(diff, .binary)
  }
  
  func testTrackingBranch() throws
  {
    let remoteName = "origin"
    let masterBranchName = "master"
    let remoteBranchName = remoteName +/ masterBranchName
    
    makeRemoteRepo()
    commit(newTextFile: FileName.file1, content: "remote",
           repository: remoteRepository)
      try repository.addRemote(named: remoteName,
                               url: URL(fileURLWithPath: remoteRepoPath))
      _ = try repository.executeGit(args: ["fetch", remoteName], writes: true)
      _ = try repository.executeGit(args: ["branch", "-u", remoteBranchName],
                                    writes: true)
    
    repository.config.invalidate()
    
    let masterBranch = try XCTUnwrap(repository.localBranch(named: masterBranchName))
    
    XCTAssertEqual(masterBranch.trackingBranchName, remoteBranchName)
    
    let localBranch = try XCTUnwrap(repository.localTrackingBranch(
          forBranchRef: RefPrefixes.remotes +/ remoteName +/ masterBranchName))
    
    XCTAssertEqual(localBranch.name, RefPrefixes.heads + "master")
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
