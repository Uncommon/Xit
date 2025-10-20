import XCTest
@testable import Xit

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
    let match = { (change: FileChange) in change.path == fileName }
    
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
    let match = { (change: FileChange) in change.path == fileName }
    
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
