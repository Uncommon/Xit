import XCTest
@testable import Xit

class IndexTreeTest: XTTest
{
  func indexTreeStatus(at path: String) -> DeltaStatus?
  {
    let selection = StagingSelection(repository: repository)
    let root = selection.fileList.treeRoot(oldTree: nil)
    guard let node = root.fileChangeNode(path: path)
    else { return nil }
    
    return node.fileChange.change
  }
  
  func addAndDelete(path: String)
  {
    let fullPath = repoPath.appending(pathComponent: path)
    
    XCTAssertTrue(commitNewTextFile(path, content: "text"))
    XCTAssertNoThrow(try FileManager.default.removeItem(atPath: fullPath))
    XCTAssertNoThrow(try repository.stage(file: path))
    XCTAssertNoThrow(try repository.commit(message: "delete", amend: false, outputBlock: nil))
  }
  
  func testNewFile()
  {
    let file2Name = "file2.txt"
    
    writeText("text", toFile: file2Name)
    XCTAssertNoThrow(try repository.stage(file: file2Name))
    
    XCTAssertEqual(indexTreeStatus(at: file2Name), .added)
  }
  
  func testModifiedFile()
  {
    writeText("modified", toFile: file1Name)
    XCTAssertNoThrow(try repository.stage(file: file1Name))
    
    XCTAssertEqual(indexTreeStatus(at: file1Name), .modified)
  }
  
  func testAddSubFile()
  {
    let file2Path = "folder/file2.txt"
    
    writeText("text", toFile: file2Path)
    XCTAssertNoThrow(try repository.stage(file: file2Path))
    
    XCTAssertEqual(indexTreeStatus(at: file2Path), .added)
  }
  
  func testAddSubSubFile()
  {
    let file2Path = "folder/folder2/file2.txt"
    
    writeText("text", toFile: file2Path)
    XCTAssertNoThrow(try repository.stage(file: file2Path))
    
    XCTAssertEqual(indexTreeStatus(at: file2Path), .added)
  }
  
  func testDeleteFile()
  {
    let file2Name = "file2.txt"
    
    addAndDelete(path: file2Name)
    XCTAssertEqual(indexTreeStatus(at: file2Name), .deleted)
  }
  
  func testDeleteSubFile()
  {
    let file2Name = "folder/file2.txt"
    
    addAndDelete(path: file2Name)
    XCTAssertEqual(indexTreeStatus(at: file2Name), .deleted)
  }
  
  func testDeleteSubSubFile()
  {
    let file2Name = "folder/folder2/file2.txt"
    
    addAndDelete(path: file2Name)
    XCTAssertEqual(indexTreeStatus(at: file2Name), .deleted)
  }
}
