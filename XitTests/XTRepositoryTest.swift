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
    let masterBranch: LocalBranchRefName = "main"
    let testBranch1: LocalBranchRefName = "testBranch1"
    let testBranch2: LocalBranchRefName = "testBranch2"

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
    guard let headOID = repository.headOID
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
    XCTAssertEqual(repository.headRefName?.fullPath, "refs/heads/main")
    XCTAssertNotNil(repository.headSHA)
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
    let blob = try XCTUnwrap(repository.fileBlob(ref: GeneralRefName.head,
                                                 path: TestFileName.file1.rawValue))
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
    let mainBranchName = "main"
    let remoteBranchName = try XCTUnwrap(RemoteBranchRefName(remote: remoteName, branch: mainBranchName))

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
    
    let masterBranch = try XCTUnwrap(repository.localBranch(named: .named(mainBranchName)!))

    XCTAssertEqual(masterBranch.trackingBranchName?.fullPath, remoteBranchName.fullPath)
    
    let localBranch = try XCTUnwrap(repository.localTrackingBranch(
      forBranch: remoteBranchName))
    
    XCTAssertEqual(localBranch.referenceName.name, mainBranchName)
  }
}

extension PatchMaker.PatchResult: @retroactive Equatable
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
