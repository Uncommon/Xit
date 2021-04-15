import XCTest
@testable import Xit

class IndexTreeTest: XTTest
{
  override func setUpWithError() throws
  {
    try super.setUpWithError()

    // A second commit is needed for amending tests
    try execute(in: repository) {
      CommitFiles("second") {
        Write("second", to: .file1)
      }
    }
  }
  
  func indexTreeStatus(at path: String,
                       amending: Bool = false) -> DeltaStatus?
  {
    repository.invalidateIndex()
    
    let selection = amending ? AmendingSelection(repository: repository)
                             : StagingSelection(repository: repository)
    let root = selection.fileList.treeRoot(oldTree: nil)
    root.dump()
    guard let node = root.fileChangeNode(path: path)
    else { return nil }
    
    return node.fileChange.status
  }
  
  func addAndStageDelete(path: String) throws
  {
    try execute(in: repository) {
      CommitFiles {
        Write("text", to: path)
      }
      Delete(path)
      Stage(path)
    }
  }
  
  func testSimpleAmend()
  {
    XCTAssertEqual(indexTreeStatus(at: FileName.file1, amending: true), .modified)
  }
  
  func testNewFile() throws
  {
    try execute(in: repository) {
      Write("text", to: .file2)
      Stage(.file2)
    }

    XCTAssertEqual(indexTreeStatus(at: FileName.file2, amending: false), .added)
    XCTAssertEqual(indexTreeStatus(at: FileName.file2, amending: true), .added)
  }
  
  func testModifiedFile() throws
  {
    try execute(in: repository) {
      Write("modified", to: .file1)
      Stage(.file1)
    }

    XCTAssertEqual(indexTreeStatus(at: FileName.file1, amending: false), .modified)
    XCTAssertEqual(indexTreeStatus(at: FileName.file1, amending: true), .modified)
  }

  func testAddSubFile() throws
  {
    try execute(in: repository) {
      Write("text", to: .subFile2)
      Stage(.subFile2)
    }

    XCTAssertEqual(indexTreeStatus(at: FileName.subFile2), .added)
  }
  
  func testAddSubSubFile() throws
  {
    try execute(in: repository) {
      Write("text", to: .subSubFile2)
      Stage(.subSubFile2)
    }

    XCTAssertEqual(indexTreeStatus(at: FileName.subSubFile2, amending: false), .added)
    XCTAssertEqual(indexTreeStatus(at: FileName.subSubFile2, amending: true), .added)
  }
  
  func testDeleteFile() throws
  {
    try addAndStageDelete(path: FileName.file2)
    XCTAssertEqual(indexTreeStatus(at: FileName.file2, amending: false), .deleted)
    // We're amending the add with a delete, so the file is absent from the tree
    XCTAssertNil(indexTreeStatus(at: FileName.file2, amending: true))
  }
  
  func testDeleteSubFile() throws
  {
    try addAndStageDelete(path: FileName.subFile2)
    XCTAssertEqual(indexTreeStatus(at: FileName.subFile2, amending: false), .deleted)
    XCTAssertNil(indexTreeStatus(at: FileName.subFile2, amending: true))
  }
  
  func testDeleteSubSubFile() throws
  {
    try addAndStageDelete(path: FileName.subSubFile2)
    XCTAssertEqual(indexTreeStatus(at: FileName.subSubFile2, amending: false), .deleted)
    XCTAssertNil(indexTreeStatus(at: FileName.subSubFile2, amending: true))
  }
}
