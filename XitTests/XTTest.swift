import Foundation
import XCTest
@testable import Xit

class XTTest: XCTestCase
{
  var repoPath: String!
  var remoteRepoPath: String!

  var repoController: GitRepositoryController!
  var repository, remoteRepository: XTRepository!

  // TODO: delete these in favor of TestFileName
  enum FileName
  {
    // These are not cases because then you'd have to say .rawvalue all the time
    static let file1 = "file1.txt"
    static let file2 = "file2.txt"
    static let file3 = "file3.txt"
    static let subFile2 = "folder/file2.txt"
    static let subSubFile2 = "folder/folder2/file2.txt"
    static let added = "added.txt"
    static let untracked = "untracked.txt"
  }
  
  var file1Path: String
  { return repoPath.appending(pathComponent: FileName.file1) }
  
  static func createRepo(atPath repoPath: String) -> XTRepository?
  {
    NSLog("[createRepo] repoName=\(repoPath)")
    
    let fileManager = FileManager.default
    
    if fileManager.fileExists(atPath: repoPath) {
      do {
        try fileManager.removeItem(atPath: repoPath)
      }
      catch {
        XCTFail("Couldn't make way for repository: \(repoPath)")
        return nil
      }
    }
    
    do {
      try fileManager.createDirectory(atPath: repoPath,
                                      withIntermediateDirectories: true,
                                      attributes: nil)
    }
    catch {
      XCTFail("Couldn't create repository: \(repoPath)")
      return nil
    }
    
    let repoURL = URL(fileURLWithPath: repoPath)
    guard let repo = XTRepository(emptyURL: repoURL)
    else {
      XCTFail("initializeRepository '\(repoPath)' FAIL")
      return nil
    }
    guard fileManager.fileExists(atPath: repoPath.appending(pathComponent: ".git"))
    else {
      XCTFail(".git not found")
      return nil
    }

    return repo
  }
  
  override func setUpWithError() throws
  {
    try super.setUpWithError()

    repoPath = NSString.path(withComponents: ["private",
                                              NSTemporaryDirectory(),
                                              "testRepo"])
    repository = try XCTUnwrap(XTTest.createRepo(atPath: repoPath))
    repoController = GitRepositoryController(repository: repository)
    try addInitialRepoContent()
  }
  
  override func tearDown()
  {
    waitForRepoQueue()
    
    XCTAssertNoThrow(try retryDelete(path: repoPath))
    if let remoteRepoPath = self.remoteRepoPath {
      XCTAssertNoThrow(try retryDelete(path: remoteRepoPath))
    }
    super.tearDown()
  }
  
  func retryDelete(path: String) throws
  {
    var error: Error? = nil
    
    for _ in 1...5 {
      do {
        try FileManager.default.removeItem(atPath: path)
        return
      }
      catch let e {
        error = e
      }
    }
    try error.map { throw $0 }
  }
  
  func waitForRepoQueue()
  {
    wait(for: repository)
  }
  
  func wait(for repository: XTRepository)
  {
    repository.controller?.waitForQueue()
  }
  
  func addInitialRepoContent() throws
  {
    try execute(in: repository) {
      CommitFiles {
        Write("some text", to: .file1)
      }
    }
  }
  
  func makeRemoteRepo()
  {
    let parentPath = repoPath.deletingLastPathComponent
    
    remoteRepoPath = parentPath.appending(pathComponent: "remotetestrepo")
    remoteRepository = XTTest.createRepo(atPath: remoteRepoPath)
    XCTAssertNotNil(remoteRepository)
  }

  func assertContent(_ text: String, file: String,
                     line: UInt = #line, sourceFile: StaticString = #file)
  {
    guard let content = try? String(contentsOfFile: repoPath +/ file)
    else {
      XCTFail("can't load file", file: sourceFile, line: line)
      return
    }
    guard content == text
    else {
      XCTFail("content mismatch", file: sourceFile, line: line)
      return
    }
  }
  
  func makeStash() throws
  {
    try execute(in: repository) {
      Write("stashy", to: .file1)
      Write("new", to: .untracked)
      Write("add", to: .added)
      Stage(.added)
      SaveStash()
    }
  }
}

extension RepositoryController
{
  func waitForQueue()
  {
    queue.wait()
    WaitForQueue(DispatchQueue.main)
  }
}

extension DeltaStatus: CustomStringConvertible
{
  public var description: String
  {
    switch self {
      case .unmodified:
        return "unmodified"
      case .added:
        return "added"
      case .deleted:
        return "deleted"
      case .modified:
        return "modified"
      case .renamed:
        return "renamed"
      case .copied:
        return "copied"
      case .ignored:
        return "ignored"
      case .untracked:
        return "untracked"
      case .typeChange:
        return "typeChange"
      case .conflict:
        return "conflict"
      case .mixed:
        return "mixed"
    }
  }
}
