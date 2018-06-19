import XCTest
@testable import Xit

class IndexTreeTest: XTTest
{
  override func setUp()
  {
    super.setUp()
    
    // A second commit is needed for amending tests
    writeTextToFile1("second")
    XCTAssertNoThrow(try repository.stage(file: file1Name))
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
    XCTAssertEqual(indexTreeStatus(at: file1Name, amending: true), .modified)
  }
  
  func testNewFile()
  {
    let file2Name = "file2.txt"
    
    write(text: "text", to: file2Name)
    XCTAssertNoThrow(try repository.stage(file: file2Name))
    
    XCTAssertEqual(indexTreeStatus(at: file2Name, amending: false), .added)
    XCTAssertEqual(indexTreeStatus(at: file2Name, amending: true), .added)
  }
  
  func testModifiedFile()
  {
    write(text: "modified", to: file1Name)
    XCTAssertNoThrow(try repository.stage(file: file1Name))
    
    XCTAssertEqual(indexTreeStatus(at: file1Name, amending: false), .modified)
    XCTAssertEqual(indexTreeStatus(at: file1Name, amending: true), .modified)
  }

  func testAddSubFile()
  {
    let file2Path = "folder/file2.txt"
    
    XCTAssertTrue(write(text: "text", to: file2Path))
    XCTAssertNoThrow(try repository.stage(file: file2Path))
    
    XCTAssertEqual(indexTreeStatus(at: file2Path), .added)
  }
  
  func testAddSubSubFile()
  {
    let file2Path = "folder/folder2/file2.txt"
    
    write(text: "text", to: file2Path)
    XCTAssertNoThrow(try repository.stage(file: file2Path))
    
    XCTAssertEqual(indexTreeStatus(at: file2Path, amending: false), .added)
    XCTAssertEqual(indexTreeStatus(at: file2Path, amending: true), .added)
  }
  
  func testDeleteFile()
  {
    let file2Name = "file2.txt"
    
    addAndStageDelete(path: file2Name)
    XCTAssertEqual(indexTreeStatus(at: file2Name, amending: false), .deleted)
    // We're amending the add with a delete, so the file is absent from the tree
    XCTAssertNil(indexTreeStatus(at: file2Name, amending: true))
  }
  
  func testDeleteSubFile()
  {
    let file2Name = "folder/file2.txt"
    
    addAndStageDelete(path: file2Name)
    XCTAssertEqual(indexTreeStatus(at: file2Name, amending: false), .deleted)
    XCTAssertNil(indexTreeStatus(at: file2Name, amending: true))
  }
  
  func testDeleteSubSubFile()
  {
    let file2Name = "folder/folder2/file2.txt"
    
    addAndStageDelete(path: file2Name)
    XCTAssertEqual(indexTreeStatus(at: file2Name, amending: false), .deleted)
    XCTAssertNil(indexTreeStatus(at: file2Name, amending: true))
  }
}
