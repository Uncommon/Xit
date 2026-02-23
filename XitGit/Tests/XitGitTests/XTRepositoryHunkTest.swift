import XCTest
@testable import XitGit
import XitGitTestSupport

class XTRepositoryHunkTest: XTTest
{
  let testBundle = Bundle.module
  let loremName = "lorem.txt"
  var loremURL, lorem2URL: URL!
  var loremRepoURL: URL!

  override func setUp()
  {
    super.setUp()
    loremURL = testBundle.url(forResource: "lorem", withExtension: "txt")!
    lorem2URL = testBundle.url(forResource: "lorem2", withExtension: "txt")!
    loremRepoURL = repository.repoURL +/ loremName
  }
  
  /// Returns the content of lorem.txt in the index
  func readLoremIndexText() -> String?
  {
    var encoding = String.Encoding.utf8
    guard let indexData = repository.stagedBlob(file: loremName)?.makeData()
    else { return nil }
    
    return String(data: indexData, usedEncoding: &encoding)
  }
  
  /// Tests staging the first hunk of a changed file
  func testStageHunk() throws
  {
    let data = try Data(contentsOf: lorem2URL)

    try execute(in: repository) {
      CopyFile(from: loremURL, to: loremName)
      Stage(loremName)
      WriteData(data, to: loremName)
    }

    let diffResult = try XCTUnwrap(repository.unstagedDiff(file: loremName))
    let patch = try XCTUnwrap(diffResult.extractPatch())
    let hunk = patch.hunk(at: 0)!
    
    try repository.patchIndexFile(path: loremName, hunk: hunk, stage: true)
    
    let indexText = readLoremIndexText()!

    XCTAssert(indexText.hasPrefix("""
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec nec maximus mauris. Quisque varius nisi ac augue rutrum ullamcorper. Sed tincidunt leo in erat commodo, tempor ultricies quam sagittis.
        Duis risus quam, malesuada vel ante at, tincidunt sagittis erat. Phasellus a ante erat. Donec tristique lorem leo, sit amet congue est convallis vitae. Vestibulum a faucibus nisl. Pellentesque vitae sem vitae enim pharetra lacinia.
        Pellentesque mattis ante eget dignissim cursus. Nullam lacinia sit amet sapien ac feugiat. Aenean sagittis eros dignissim volutpat faucibus. Proin laoreet tempus nunc in suscipit.

        """))
  }
  
  /// Tests unstaging the first hunk of a staged file
  func testUnstageHunk() throws
  {
    let loremData = try Data(contentsOf: lorem2URL)

    try execute(in: repository) {
      CommitFiles("lorem") {
        CopyFile(from: loremURL, to: loremName)
      }
      WriteData(loremData, to: loremName)
      Stage(loremName)
    }

    let diffResult = try XCTUnwrap(repository.stagedDiff(file: loremName))
    let patch = try XCTUnwrap(diffResult.extractPatch())
    let hunk = try XCTUnwrap(patch.hunk(at: 0))
    
    try repository.patchIndexFile(path: loremName, hunk: hunk, stage: false)
    
    let indexText = readLoremIndexText()!
    
    XCTAssert(indexText.hasPrefix("""
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec nec maximus mauris. Quisque varius nisi ac augue rutrum ullamcorper. Sed tincidunt leo in erat commodo, tempor ultricies quam sagittis.
        Duis risus quam, malesuada vel ante at, tincidunt sagittis erat. Phasellus a ante erat. Donec tristique lorem leo, sit amet congue est convallis vitae. Vestibulum a faucibus nisl. Pellentesque vitae sem vitae enim pharetra lacinia.
        Pellentesque mattis ante eget dignissim cursus. Nullam lacinia sit amet sapien ac feugiat. Aenean sagittis eros dignissim volutpat faucibus. Proin laoreet tempus nunc in suscipit.
        Cras vestibulum id neque eu imperdiet. Pellentesque a lacus ipsum. Nulla ultrices consectetur congue.
        """))
  }
  
  /// Tests staging a new file as a hunk
  func testStageNewHunk() throws
  {
    try execute(in: repository) {
      CopyFile(from: loremURL, to: loremName)
    }

    let diffResult = try XCTUnwrap(repository.unstagedDiff(file: loremName))
    let patch = try XCTUnwrap(diffResult.extractPatch())
    let hunk = try XCTUnwrap(patch.hunk(at: 0))

    try repository.patchIndexFile(path: loremName, hunk: hunk, stage: true)
    
    var encoding = String.Encoding.utf8
    let stagedText = readLoremIndexText()!
    let loremData = try Data(contentsOf: loremURL)
    let loremText = String(data: loremData, usedEncoding: &encoding)!
    
    XCTAssertEqual(stagedText, loremText)
  }
  
  /// Tests staging a deleted file as a hunk
  func testStageDeletedHunk() throws
  {
    try execute(in: repository) {
      Delete(.file1)
    }

    let diffResult = try XCTUnwrap(repository.unstagedDiff(file: TestFileName.file1.rawValue))
    let patch = try XCTUnwrap(diffResult.extractPatch())
    let hunk = try XCTUnwrap(patch.hunk(at: 0))
    
    try repository.patchIndexFile(path: TestFileName.file1.rawValue, hunk: hunk, stage: true)
    
    let status = try repository.status(file: TestFileName.file1.rawValue)
    
    XCTAssertEqual(status.0, DeltaStatus.unmodified)
    XCTAssertEqual(status.1, DeltaStatus.deleted)
  }
  
  /// Tests unstaging a new file as a hunk
  func testUnstageNewHunk() throws
  {
    try execute(in: repository) {
      CopyFile(from: loremURL, to: loremName)
      Stage(loremName)
    }

    let diffResult = try XCTUnwrap(repository.stagedDiff(file: loremName))
    let patch = try XCTUnwrap(diffResult.extractPatch())
    let hunk = try XCTUnwrap(patch.hunk(at: 0))
    
    try repository.patchIndexFile(path: loremName, hunk: hunk, stage: false)
    
    let status = try repository.status(file: loremName)
    
    XCTAssertEqual(status.0, DeltaStatus.untracked)
    XCTAssertEqual(status.1, DeltaStatus.unmodified) // There is no "absent"
  }
  
  /// Tests unstaging a deleted file as a hunk
  func testUnstageDeletedHunk() throws
  {
    try execute(in: repository) {
      Delete(.file1)
      Stage(.file1)
    }

    let diffResult = try XCTUnwrap(repository.stagedDiff(file: TestFileName.file1.rawValue))
    let patch = try XCTUnwrap(diffResult.extractPatch())
    let hunk = try XCTUnwrap(patch.hunk(at: 0))
    
    try repository.patchIndexFile(path: TestFileName.file1.rawValue, hunk: hunk, stage: false)
    
    let status = try repository.status(file: TestFileName.file1.rawValue)
    
    XCTAssertEqual(status.0, DeltaStatus.deleted)
    XCTAssertEqual(status.1, DeltaStatus.unmodified)
  }
}
