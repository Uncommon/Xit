import XCTest
@testable import XitGit
import XitGitTestSupport

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
    
    let selection = StagingSelection(repository: repository, amending: amending)
    let root = selection.fileList.treeRoot(oldTree: nil)
    root.dump()
    guard let node = root.fileChangeNode(path: path)
    else { return nil }
    
    return node.value.status
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
    XCTAssertEqual(indexTreeStatus(at: TestFileName.file1.rawValue,
                                   amending: true), .modified)
  }
  
  func testNewFile() throws
  {
    try execute(in: repository) {
      Write("text", to: .file2)
      Stage(.file2)
    }

    XCTAssertEqual(indexTreeStatus(at: TestFileName.file2.rawValue,
                                   amending: false), .added)
    XCTAssertEqual(indexTreeStatus(at: TestFileName.file2.rawValue,
                                   amending: true), .added)
  }
  
  func testModifiedFile() throws
  {
    try execute(in: repository) {
      Write("modified", to: .file1)
      Stage(.file1)
    }

    XCTAssertEqual(indexTreeStatus(at: TestFileName.file1.rawValue,
                                   amending: false), .modified)
    XCTAssertEqual(indexTreeStatus(at: TestFileName.file1.rawValue,
                                   amending: true), .modified)
  }

  func testAddSubFile() throws
  {
    try execute(in: repository) {
      Write("text", to: .subFile2)
      Stage(.subFile2)
    }

    XCTAssertEqual(indexTreeStatus(at: TestFileName.subFile2.rawValue), .added)
  }
  
  func testAddSubSubFile() throws
  {
    try execute(in: repository) {
      Write("text", to: .subSubFile2)
      Stage(.subSubFile2)
    }

    XCTAssertEqual(indexTreeStatus(at: TestFileName.subSubFile2.rawValue,
                                   amending: false), .added)
    XCTAssertEqual(indexTreeStatus(at: TestFileName.subSubFile2.rawValue,
                                   amending: true), .added)
  }
  
  func testDeleteFile() throws
  {
    try addAndStageDelete(path: TestFileName.file2.rawValue)
    XCTAssertEqual(indexTreeStatus(at: TestFileName.file2.rawValue, amending: false), .deleted)
    // We're amending the add with a delete, so the file is absent from the tree
    XCTAssertNil(indexTreeStatus(at: TestFileName.file2.rawValue, amending: true))
  }
  
  func testDeleteSubFile() throws
  {
    try addAndStageDelete(path: TestFileName.subFile2.rawValue)
    XCTAssertEqual(indexTreeStatus(at: TestFileName.subFile2.rawValue, amending: false), .deleted)
    XCTAssertNil(indexTreeStatus(at: TestFileName.subFile2.rawValue, amending: true))
  }
  
  func testDeleteSubSubFile() throws
  {
    try addAndStageDelete(path: TestFileName.subSubFile2.rawValue)
    XCTAssertEqual(indexTreeStatus(at: TestFileName.subSubFile2.rawValue, amending: false), .deleted)
    XCTAssertNil(indexTreeStatus(at: TestFileName.subSubFile2.rawValue, amending: true))
  }
}
