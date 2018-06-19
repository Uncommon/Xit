import XCTest
@testable import Xit

class IndexTreeTest: XTTest
{
  override func setUp()
  {
    super.setUp()
    
    // A second commit is needed for amending tests
    writeTextToFile1("second")
    XCTAssertNoThrow(try repository.stage(file: FileName.file1))
    XCTAssertNoThrow(try repository.commit(message: "second", amend: false,
                                           outputBlock: nil))
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
    
    return node.fileChange.change
  }
  
  func addAndStageDelete(path: String)
  {
    let fullPath = repoPath.appending(pathComponent: path)
    
    XCTAssertTrue(commit(newTextFile: path, content: "text"))
    XCTAssertNoThrow(try FileManager.default.removeItem(atPath: fullPath))
    XCTAssertNoThrow(try repository.stage(file: path))
  }
  
  func testSimpleAmend()
  {
    XCTAssertEqual(indexTreeStatus(at: FileName.file1, amending: true), .modified)
  }
  
  func testNewFile()
  {
    write(text: "text", to: FileName.file2)
    XCTAssertNoThrow(try repository.stage(file: FileName.file2))
    
    XCTAssertEqual(indexTreeStatus(at: FileName.file2, amending: false), .added)
    XCTAssertEqual(indexTreeStatus(at: FileName.file2, amending: true), .added)
  }
  
  func testModifiedFile()
  {
    write(text: "modified", to: FileName.file1)
    XCTAssertNoThrow(try repository.stage(file: FileName.file1))
    
    XCTAssertEqual(indexTreeStatus(at: FileName.file1, amending: false), .modified)
    XCTAssertEqual(indexTreeStatus(at: FileName.file1, amending: true), .modified)
  }

  func testAddSubFile()
  {
    XCTAssertTrue(write(text: "text", to: FileName.subFile2))
    XCTAssertNoThrow(try repository.stage(file: FileName.subFile2))
    
    XCTAssertEqual(indexTreeStatus(at: FileName.subFile2), .added)
  }
  
  func testAddSubSubFile()
  {
    write(text: "text", to: FileName.subSubFile2)
    XCTAssertNoThrow(try repository.stage(file: FileName.subSubFile2))
    
    XCTAssertEqual(indexTreeStatus(at: FileName.subSubFile2, amending: false), .added)
    XCTAssertEqual(indexTreeStatus(at: FileName.subSubFile2, amending: true), .added)
  }
  
  func testDeleteFile()
  {
    addAndStageDelete(path: FileName.file2)
    XCTAssertEqual(indexTreeStatus(at: FileName.file2, amending: false), .deleted)
    // We're amending the add with a delete, so the file is absent from the tree
    XCTAssertNil(indexTreeStatus(at: FileName.file2, amending: true))
  }
  
  func testDeleteSubFile()
  {
    addAndStageDelete(path: FileName.subFile2)
    XCTAssertEqual(indexTreeStatus(at: FileName.subFile2, amending: false), .deleted)
    XCTAssertNil(indexTreeStatus(at: FileName.subFile2, amending: true))
  }
  
  func testDeleteSubSubFile()
  {
    addAndStageDelete(path: FileName.subSubFile2)
    XCTAssertEqual(indexTreeStatus(at: FileName.subSubFile2, amending: false), .deleted)
    XCTAssertNil(indexTreeStatus(at: FileName.subSubFile2, amending: true))
  }
}
