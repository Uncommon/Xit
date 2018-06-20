import Foundation
import XCTest
@testable import Xit

class XTTest: XCTestCase
{
  var repoPath: String!
  var remoteRepoPath: String!
  
  var repository, remoteRepository: XTRepository!
  
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
  
  var file1Path: String { return repoPath.appending(pathComponent: FileName.file1) }
  
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
  
  override func setUp()
  {
    super.setUp()
    
    repoPath = NSString.path(withComponents: ["private",
                                              NSTemporaryDirectory(),
                                              "testRepo"])
    repository = XTTest.createRepo(atPath: repoPath)
    addInitialRepoContent()
  }
  
  override func tearDown()
  {
    waitForRepoQueue()
    
    let fileManager = FileManager.default
    
    XCTAssertNoThrow(try fileManager.removeItem(atPath: repoPath))
    if let remoteRepoPath = self.remoteRepoPath {
      XCTAssertNoThrow(try fileManager.removeItem(atPath: remoteRepoPath))
    }
    super.tearDown()
  }
  
  func waitForRepoQueue()
  {
    wait(for: repository)
  }
  
  func wait(for repository: XTRepository)
  {
    repository.queue.wait()
    WaitForQueue(DispatchQueue.main)
  }
  
  func addInitialRepoContent()
  {
    XCTAssertTrue(commit(newTextFile: FileName.file1, content: "some text"))
  }
  
  func makeRemoteRepo()
  {
    let parentPath = repoPath.deletingLastPathComponent
    
    remoteRepoPath = parentPath.appending(pathComponent: "remotetestrepo")
    remoteRepository = XTTest.createRepo(atPath: remoteRepoPath)
    XCTAssertNotNil(remoteRepository)
  }
  
  @discardableResult
  func commit(newTextFile name: String, content: String) -> Bool
  {
    return commit(newTextFile: name, content: content, repository: repository)
  }

  @discardableResult
  func commit(newTextFile name: String, content: String,
              repository: XTRepository) -> Bool
  {
    let basePath = repository.repoURL.path
    let filePath = basePath.appending(pathComponent: name)
    
    do {
      try? FileManager.default.createDirectory(
            atPath: filePath.deletingLastPathComponent,
            withIntermediateDirectories: true, attributes: nil)
      try content.write(toFile: filePath, atomically: true, encoding: .ascii)
    }
    catch {
      return false
    }
    
    var result = true
    let semaphore = DispatchSemaphore(value: 0)
    
    repository.queue.executeOffMainThread {
      defer {
        semaphore.signal()
      }
      do {
        try repository.stage(file: name)
        try repository.commit(message: "new \(name)", amend: false,
                              outputBlock: nil)
      }
      catch {
        result = false
      }
    }
    return (semaphore.wait(timeout: .distantFuture) == .success) && result
  }
  
  @discardableResult
  func write(text: String, to path: String) -> Bool
  {
    return write(text: text, to: path, repository: repository)
  }
  
  @discardableResult
  func write(text: String, to path: String, repository: XTRepository) -> Bool
  {
    do {
      let fullPath = repoPath.appending(pathComponent: path)
      
      try? FileManager.default.createDirectory(
            atPath: fullPath.deletingLastPathComponent,
            withIntermediateDirectories: true, attributes: nil)
      try text.write(toFile: fullPath, atomically: true, encoding: .utf8)
      repository.invalidateIndex()
    }
    catch {
      XCTFail("write to \(path) failed")
      return false
    }
    return true
  }
  
  @discardableResult
  func writeTextToFile1(_ text: String) -> Bool
  {
    return write(text: text, to: FileName.file1)
  }
  
  func makeStash() throws
  {
    writeTextToFile1("stashy")
    write(text: "new", to: FileName.untracked)
    write(text: "add", to: FileName.added)
    try repository.stage(file: FileName.added)
    try repository.saveStash(name: "", includeUntracked: true)
  }

  func makeTiffFile(_ name: String) throws
  {
    let tiffURL = repository.fileURL(name)
    
    try NSImage(named: .actionTemplate)?.tiffRepresentation?.write(to: tiffURL)
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
