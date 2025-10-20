import XCTest
@testable import Xit

class XTEmptyRepositoryTest: XTTest
{
  override func addInitialRepoContent() throws
  {
  }

  func testEmptyRepositoryHead()
  {
    XCTAssertFalse(repository.hasHeadReference())
    XCTAssertEqual(repository.parentTree(), SHA.emptyTree.rawValue)
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
