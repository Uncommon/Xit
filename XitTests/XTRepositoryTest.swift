import XCTest
@testable import Xit

extension Xit.PatchMaker.PatchResult
{
  func extractPatch() -> (any Patch)?
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
  
  func testWorkspaceTextFile() throws
  {
    let textName = "text"

    try execute(in: repository) {
      Write("some text", to: textName)
    }
    XCTAssertTrue(repository.isTextFile(textName, context: .workspace))
  }
  
  func testWorkspaceBinaryFile() throws
  {
    let tiffName = TestFileName.binary

    try execute(in: repository) {
      MakeTiffFile(tiffName)
    }
    XCTAssertFalse(repository.isTextFile(tiffName.rawValue, context: .workspace))
  }
  
  func testIndexTextFile() throws
  {
    let textName = "text"

    try execute(in: repository) {
      Write("some text", to: textName)
      Stage(textName)
    }
    XCTAssertTrue(repository.isTextFile(textName, context: .index))
  }
  
  func testIndexBinaryFile() throws
  {
    let tiffName = TestFileName.binary
    
    try execute(in: repository) {
      MakeTiffFile(tiffName)
      Stage(tiffName)
    }
    XCTAssertFalse(repository.isTextFile(tiffName.rawValue, context: .index))
  }
  
  func testCommitTextFile() throws
  {
    let textName = "text"

    try execute(in: repository) {
      CommitFiles("text") {
        Write("some text", to: textName)
      }
    }

    let headSHA = try XCTUnwrap(repository.headSHA)
    let headCommit = try XCTUnwrap(repository.commit(forSHA: headSHA))

    XCTAssertTrue(repository.isTextFile(textName, context: .commit(headCommit)))
  }
  
  func testCommitBinaryFile() throws
  {
    let tiffName = TestFileName.binary

    try execute(in: repository) {
      CommitFiles() {
        MakeTiffFile(tiffName)
      }
    }

    let headCommit = try XCTUnwrap(repository.headCommit)

    XCTAssertFalse(repository.isTextFile(tiffName.rawValue,
                                         context: .commit(headCommit)))
  }
  
  func testStagedContents() throws
  {
    let content = "some content"

    try execute(in: repository) {
      Write(content, to: .file1)
    }
    XCTAssertNil(repository.contentsOfStagedFile(path: TestFileName.file1.rawValue))
    try execute(in: repository) {
      Stage(.file1)
    }
    
    let expectedContent = content.data(using: .utf8)
    let stagedContent = try XCTUnwrap(repository.contentsOfStagedFile(path: TestFileName.file1.rawValue))
    let stagedString = String(data: stagedContent, encoding: .utf8)
    
    XCTAssertEqual(stagedContent, expectedContent)
    XCTAssertEqual(stagedString, content)
    
    // Write to the workspace file, but don't stage it. The staged content
    // should be the same.
    let newContent = "new stuff"
    
    try execute(in: repository) {
      Write(newContent, to: .file1)
    }

    let stagedContent2 = try XCTUnwrap(repository.contentsOfStagedFile(path: TestFileName.file1.rawValue))
    let stagedString2 = String(data: stagedContent, encoding: .utf8)
    
    XCTAssertEqual(stagedContent2, expectedContent)
    XCTAssertEqual(stagedString2, content)
  }
}

class XTAmendTest: XTTest
{
  override func addInitialRepoContent() throws
  {
    try execute(in: repository) {
      CommitFiles("commit 1") {
        Write("text", to: .file1)
        Write("text", to: .file2)
      }
    }
  }
  
  func addSecondCommit() throws
  {
    try execute(in: repository) {
      CommitFiles("commit 2") {
        Write("more", to: .file1)
        Delete(.file2)
        Write("more", to: .file3)
      }
    }
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
    let headCommit = try XCTUnwrap(repository.headCommit)
    
    try addSecondCommit()
    
    let normalStatus = repository.stagingChanges
    let amendStatus = repository.amendingChanges(parent: headCommit)
    
    XCTAssertEqual(normalStatus.count, 0)
    XCTAssertEqual(amendStatus.count, 3)
  }
  
  // Modify a file added in the last commit, then check the amend status
  func testAmendModifyAdded() throws
  {
    let headCommit = try XCTUnwrap(repository.headCommit)

    try addSecondCommit()
    try execute(in: repository) {
      Write("third", to: .file3)
    }

    let amendChange = repository.amendingChanges(parent: headCommit)
    let file3Change = try XCTUnwrap(amendChange.first { $0.path == TestFileName.file3.rawValue })

    XCTAssertEqual(amendChange.count, 3)
    XCTAssertEqual(file3Change.status, DeltaStatus.added)
  }
  
  // Delete a file added in the last commit, then check the amend status
  func testAmendDeleteAdded() throws
  {
    let headCommit = try XCTUnwrap(repository.headCommit)
    let fileName = TestFileName.file3.rawValue

    try addSecondCommit()
    try FileManager.default.removeItem(at: repository.fileURL(fileName))
    
    let amendStatus = repository.amendingChanges(parent: headCommit)
    guard let file3Change = amendStatus.first(where: { $0.path == fileName })
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
    let headCommit = try XCTUnwrap(repository.headCommit)
    let fileName = TestFileName.file3.rawValue

    try addSecondCommit()
    try repository.amendUnstage(file: fileName)
    
    let amendStatus = repository.amendingChanges(parent: headCommit)
    let file3Change = try XCTUnwrap(
          amendStatus.first(where: { $0.path == fileName }))
    
    XCTAssertEqual(file3Change.status, DeltaStatus.unmodified)
  }
  
  // Test amend status for a file deleted in the head commit
  func testUnstageDeleted() throws
  {
    let headCommit = try XCTUnwrap(repository.headCommit)
    let fileName = TestFileName.file2.rawValue

    try addSecondCommit()
    try repository.amendUnstage(file: fileName)
    
    let amendChange = repository.amendingChanges(parent: headCommit)
    let file2Change = try XCTUnwrap(
          amendChange.first(where: { $0.path == fileName }))
    
    XCTAssertEqual(file2Change.status, DeltaStatus.unmodified)
  }
  
  // Stage & unstage a new file in amend mode
  func testAddedNew() throws
  {
    let headCommit = try XCTUnwrap(repository.headCommit)
    let fileName = TestFileName.file4.rawValue
    let match = { (change: FileStagingChange) in change.path == fileName }
    
    try addSecondCommit()
    try execute(in: repository) {
      Write("text", to: fileName)
    }

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
    let headCommit = try XCTUnwrap(repository.headCommit)
    let fileName = TestFileName.file1.rawValue
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
    catch let error {
      XCTFail("\(name): unexpected exception \(error)", file: file, line: line)
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
    catch let error {
      XCTFail("\(name): unexpected exception: \(error)", file: file, line: line)
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

  func assertWriteAction(name: String,
                         file: StaticString = #file, line: UInt = #line,
                         @RepoActionBuilder actions: () -> [any RepoAction])
  {
    func executeActions() throws {
      try execute(in: repository, actions: actions)
    }

    setRepoWriting(repository, true)
    assertWriteFails(name: name, block: executeActions)
    setRepoWriting(repository, false)
    assertWriteSucceeds(name: name, executeActions)
  }

  func testWriteLockStage() throws
  {
    try execute(in: repository) {
      Write("modification", to: .file1)
    }

    assertWriteAction(name: "stageFile") {
      Stage(.file1)
    }
    assertWriteAction(name: "unstageFile") {
      Unstage(.file1)
    }
  }
  
  func testWriteLockStash() throws
  {
    try execute(in: repository) {
      Write("modification", to: .file1)
    }

    assertWriteAction(name: "unstageFile") {
      SaveStash("stashname")
    }
    assertWriteAction(name: "apply") {
      ApplyStash()
    }
    assertWriteAction(name: "drop") {
      DropStash()
    }
    try execute(in: repository) {
      Write("modification", to: .file1)
      SaveStash("stashname")
    }
    assertWriteAction(name: "pop") {
      PopStash()
    }
  }
  
  func testWriteLockCommit() throws
  {
    try execute(in: repository) {
      Write("change", to: .file1)
      Stage(.file1)
    }

    assertWriteAction(name: "commit") {
      CommitFiles("blah")
    }
  }
  
  func testWriteLockBranches()
  {
    let masterBranch = "master"
    let testBranch1 = "testBranch1"
    let testBranch2 = "testBranch2"
    
    assertWriteAction(name: "create") {
      CreateBranch(testBranch1)
    }
    assertWriteException(name: "rename") {
      try repository.rename(branch: testBranch1, to: testBranch2)
    }
    assertWriteAction(name: "checkout") {
      CheckOut(branch: masterBranch)
    }
    assertWriteSucceeds(name: "delete") {
      try repository.deleteBranch(testBranch2)
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
  
  func testDetachedCheckout() throws
  {
    guard let firstSHA = repository.headSHA
    else {
      XCTFail("no head SHA")
      return
    }

    try execute(in: repository) {
      Write("mash", to: .file1)
      Stage(.file1)
      CheckOut(sha: firstSHA)
    }

    guard let detachedSHA = repository.headSHA
    else {
      XCTFail("no detached head SHA")
      return
    }
    
    XCTAssertEqual(firstSHA, detachedSHA)
  }
  
  func testContents() throws
  {
    let headCommit = try XCTUnwrap(repository.headCommit)
    let contentData = repository.contentsOfFile(path: TestFileName.file1.rawValue,
                                                at: headCommit)!
    let contentString = String(data: contentData, encoding: .utf8)
    
    XCTAssertEqual(contentString, "some text")
  }
  
  func testFileBlob() throws
  {
    let blob = try XCTUnwrap(repository.fileBlob(ref: "HEAD", path: TestFileName.file1.rawValue))
    var blobString: String? = nil
    
    blob.withUnsafeBytes({ blobString = String(bytes: $0, encoding: .utf8) })
    XCTAssertEqual(blobString, "some text")
  }
  
  func testAddedChange() throws
  {
    let changes = repository.changes(for: repository.headOID!, parent: nil)
    
    XCTAssertEqual(changes.count, 1)
    
    let change = try XCTUnwrap(changes.first)
    
    XCTAssertEqual(change.path, TestFileName.file1.rawValue)
    XCTAssertEqual(change.status, DeltaStatus.added)
  }
  
  func testModifiedChange() throws
  {
    try execute(in: repository) {
      CommitFiles("#2") {
        Write("changes!", to: .file1)
        Write("new file 2", to: .file2)
      }
    }

    let changes2 = repository.changes(for: repository.headOID!, parent: nil)
    
    XCTAssertEqual(changes2.count, 2)
    
    let file1Change = try XCTUnwrap(changes2.first)
    
    XCTAssertEqual(file1Change.path, TestFileName.file1.rawValue)
    XCTAssertEqual(file1Change.status, .modified)
    
    let file2Change = changes2[1]
    
    XCTAssertEqual(file2Change.path, TestFileName.file2.rawValue)
    XCTAssertEqual(file2Change.status, .added)
  }
  
  func testDeletedChange() throws
  {
    try execute(in: repository) {
      CommitFiles("#3") {
        Delete(.file1)
      }
    }

    let changes3 = repository.changes(for: repository.headOID!, parent: nil)
    
    XCTAssertEqual(changes3.count, 1)
    
    let file1Deleted = try XCTUnwrap(changes3.first)
    
    XCTAssertEqual(file1Deleted.path, TestFileName.file1.rawValue)
    XCTAssertEqual(file1Deleted.status, .deleted)
  }
  
  func testStageUnstageAllStatus() throws
  {
    try execute(in: repository) {
      CommitFiles {
        Write("blah", to: .file2)
      }
      Write("blah", to: .file1)
      Delete(.file2)
      Write("blah", to: .file3)
    }
    try repository.stageAllFiles()
    
    var changes = repository.statusChanges(.indexOnly)
    
    XCTAssertEqual(changes.count, 2);
    XCTAssertEqual(changes[0].status, DeltaStatus.modified);
    XCTAssertEqual(changes[1].status, DeltaStatus.renamed);

    try repository.unstageAllFiles()
    changes = repository.statusChanges(.workdirOnly)
    
    XCTAssertEqual(changes.count, 2);
    XCTAssertEqual(changes[0].status, DeltaStatus.modified);
    XCTAssertEqual(changes[1].status, DeltaStatus.renamed);
  }

  func assertUnstagedChanged(ignored: Bool, recurse: Bool,
                             expectedResult: [String],
                             file: StaticString = #filePath, line: Int = #line)
  {
    let result = repository.unstagedChanges(showIgnored: ignored,
                                            recurseUntracked: recurse,
                                            useCache: false).map { $0.path }

    XCTAssertEqual(result, expectedResult)
  }

  func testIgnoredUntrackedFolders() throws
  {
    let folder1 = "folder1/"
    let folder2 = "folder2/"
    let subFile1 = folder1 + "ignored.txt"
    let subFile2 = folder2 + "untracked.txt"
    let gitignore = ".gitignore"

    try execute(in: repository) {
      Write("content", to: subFile1)
      Write("content", to: subFile2)

      Write("\(gitignore)\n\(folder1)", to: gitignore)
    }

    assertUnstagedChanged(ignored: false, recurse: false,
                          expectedResult: [folder2])
    assertUnstagedChanged(ignored: false, recurse: true,
                          expectedResult: [subFile2])
    assertUnstagedChanged(ignored: true, recurse: false,
                          expectedResult: [gitignore, folder1, folder2])
    assertUnstagedChanged(ignored: true, recurse: true,
                          expectedResult: [gitignore, subFile1, subFile2])
  }

  func testRename() throws
  {
    let newName = "renamed"
    let change = FileChange(path: newName,
                            oldPath: TestFileName.file1.rawValue,
                            change: .renamed)

    try XCTContext.runActivity(named: "Detect unstaged rename") { _ in
      try execute(in: repository) {
        RenameFile(.file1, to: newName)
      }

      XCTAssertEqual(repository.unstagedChanges(), [change])
    }

    try XCTContext.runActivity(named: "Stage renamed file") { _ in
      try execute(in: repository) {
        Stage(change)
      }

      XCTAssertEqual(repository.unstagedChanges(), [])
      XCTAssertEqual(repository.stagedChanges(), [change])
    }

    try XCTContext.runActivity(named: "Unstage renamed file") { _ in
      try execute(in: repository) {
        Unstage(change)
      }

      XCTAssertEqual(repository.unstagedChanges(), [change])
      XCTAssertEqual(repository.stagedChanges(), [])
    }
  }

  func checkDeletedDiff(_ diffResult: PatchMaker.PatchResult?,
                        file: StaticString = #file, line: UInt = #line) throws
  {
    let diffResult = try XCTUnwrap(diffResult, file: file, line: line)
    
    var makerPatch: (any Patch)? = nil
    
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
    try execute(in: repository) {
      Delete(.file1)
    }
    try checkDeletedDiff(repository.unstagedDiff(file: TestFileName.file1.rawValue))
  }

  func testStagedDeleteDiff() throws
  {
    try execute(in: repository) {
      Delete(.file1)
      Stage(.file1)
    }
    try checkDeletedDiff(repository.stagedDiff(file: TestFileName.file1.rawValue))
  }
  
  func testDeletedDiff() throws
  {
    try execute(in: repository) {
      CommitFiles("deleted") {
        Delete(.file1)
      }
    }
    
    let commit = try XCTUnwrap(GitCommit(ref: "HEAD", repository: repository.gitRepo))
    let parentOID = try XCTUnwrap(commit.parentOIDs.first)
    let diffResult = repository.diffMaker(forFile: TestFileName.file1.rawValue,
                                          commitOID: commit.id,
                                          parentOID: parentOID)!
    let patch = try XCTUnwrap(diffResult.extractPatch())
    
    XCTAssertEqual(patch.deletedLinesCount, 1)
  }
  
  func testAddedDiff() throws
  {
    let commit = try XCTUnwrap(GitCommit(ref: "HEAD", repository: repository.gitRepo))
    let diffResult = repository.diffMaker(forFile: TestFileName.file1.rawValue,
                                          commitOID: commit.id,
                                          parentOID: nil)!
    let patch = try XCTUnwrap(diffResult.extractPatch())
    
    XCTAssertEqual(patch.addedLinesCount, 1)
  }
  
  func testStagedBinaryDiff() throws
  {
    let imageName = TestFileName.tiff

    try execute(in: repository) {
      MakeTiffFile(imageName)
      Stage(imageName)
    }

    let unstagedDiffResult = try XCTUnwrap(repository.unstagedDiff(file: imageName.rawValue))
    
    XCTAssertEqual(unstagedDiffResult, .binary)
    
    let stagedDiffResult = try XCTUnwrap(repository.stagedDiff(file: imageName.rawValue))

    XCTAssertEqual(stagedDiffResult, .binary)
  }
  
  func testCommitBinaryDiff() throws
  {
    let imageName = TestFileName.tiff

    try execute(in: repository) {
      CommitFiles("image") {
        MakeTiffFile(imageName)
      }
    }

    let headCommit = try XCTUnwrap(repository.headCommit)
    let model = CommitSelection(repository: repository, commit: headCommit)
    let diff = try XCTUnwrap(model.fileList.diffForFile(imageName.rawValue))
    
    XCTAssertEqual(diff, .binary)
  }
  
  func testTrackingBranch() throws
  {
    let remoteName = "origin"
    let masterBranchName = "master"
    let remoteBranchName = try XCTUnwrap(RemoteBranchRefName(remoteName +/ masterBranchName))

    makeRemoteRepo()
    try execute(in: remoteRepository) {
      CommitFiles {
        Write("remote", to: .file1)
      }
    }
    try repository.addRemote(named: remoteName,
                             url: URL(fileURLWithPath: remoteRepoPath))
    _ = try repository.executeGit(args: ["fetch", remoteName], writes: true)
    _ = try repository.executeGit(args: ["branch", "-u", remoteBranchName.name],
                                  writes: true)
    
    repository.config.invalidate()
    
    let masterBranch = try XCTUnwrap(repository.localBranch(named: .init(masterBranchName)!))
    
    XCTAssertEqual(masterBranch.trackingBranchName, remoteBranchName.name)
    
    let localBranch = try XCTUnwrap(repository.localTrackingBranch(
      forBranch: remoteBranchName))
    
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
