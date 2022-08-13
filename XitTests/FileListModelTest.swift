import XCTest
@testable import Xit

class StringChangesRepo: StringRepository, FileChangesRepo,
    EmptyBasicRepository, EmptyCommitReferencing, EmptyFileContents,
    EmptyFileDiffing, EmptyFileStaging, EmptyFileStatusDetection
{
  typealias ID = StringOID
  typealias LocalBranch = NullLocalBranch
  typealias RemoteBranch = NullRemoteBranch
  typealias Reference = NullReference
  typealias Tag = NullTag
  typealias Tree = NullTree
}

class FileListModelTest: XTTest
{
  override func addInitialRepoContent() throws
  {
    // empty repository
  }

  func prepareSubRename() throws
  {
    try execute(in: repository) {
      CommitFiles("first") {
        Write("some text", to: .subFile1)
      }
      CommitFiles("second") {
        RenameFile(.subFile1, to: .subFile2)
        Stage(.subFile2)
      }
    }
  }

  func testCommitTreeRename() throws
  {
    try prepareSubRename()

    let headCommit = try XCTUnwrap(repository.headCommit)
    let selection = CommitSelection(repository: repository,
                                    commit: headCommit)
    let model = selection.fileList
    let change = try XCTUnwrap(model.changes.first)

    XCTAssertEqual(headCommit.message, "second\n")
    XCTAssertEqual(model.changes.count, 1)
    XCTAssertEqual(change.path, TestFileName.subFile2.rawValue)
    XCTAssertEqual(change.oldPath, TestFileName.subFile1.rawValue)
    XCTAssertEqual(change.status, .renamed)

    let root = model.treeRoot(oldTree: nil)
    let item = try XCTUnwrap(root.children?.first?
                                 .children?.first?.representedObject
                             as? CommitTreeItem)

    XCTAssertEqual(root.children?.count, 1)
    XCTAssertEqual(item.path, TestFileName.subFile2.rawValue)
    // oldPath is not currently filled in
    // XCTAssertEqual(item.oldPath, TestFileName.subFile1.rawValue)
    XCTAssertEqual(item.status, .renamed)
  }
}
