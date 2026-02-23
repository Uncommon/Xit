import Foundation
import XitGit

#if canImport(XCTest)
import XCTest

open class XTTest: XCTestCase
{
  public var repoPath: String!
  public var remoteRepoPath: String!

  public var repoController: GitRepositoryController!
  public var repository, remoteRepository: XTRepository!

  public var file1Path: String
  { repoPath.appending(pathComponent: "file1.txt") }

  open override class func setUp()
  {
    super.setUp()
    XTRepository.initialize()
  }

  public static func createRepo(atPath repoPath: String) -> XTRepository?
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
    let repo: XTRepository

    do {
      repo = try .init(emptyURL: repoURL)
    }
    catch let error {
      XCTFail("could not create repository at '\(repoPath)' - \(error)")
      return nil
    }
    guard fileManager.fileExists(atPath: repoPath.appending(pathComponent: ".git"))
    else {
      XCTFail(".git not found")
      return nil
    }

    return repo
  }

  open override func setUpWithError() throws
  {
    try super.setUpWithError()

    let testName = name.replacingOccurrences(of: "\\W", with: "-",
                                             options: .regularExpression)
      .filter { $0.isLetter || $0.isNumber || $0 == "_" }

    repoPath = FileManager.default.temporaryDirectory
      .appendingPathComponent("testRepo", isDirectory: true)
      .appendingPathComponent(testName, isDirectory: true)
      .path
    repository = try XCTUnwrap(Self.createRepo(atPath: repoPath))
    repoController = GitRepositoryController(repository: repository)
    try addInitialRepoContent()
  }

  open override func tearDown()
  {
    waitForRepoQueue()

    XCTAssertNoThrow(try retryDelete(path: repoPath))
    if let remoteRepoPath = self.remoteRepoPath {
      XCTAssertNoThrow(try retryDelete(path: remoteRepoPath))
    }
    super.tearDown()
  }

  public func retryDelete(path: String) throws
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

  public func waitForRepoQueue()
  {
    if let repository {
      wait(for: repository)
    }
  }

  public func wait(for repository: XTRepository)
  {
    repository.controller?.waitForQueue()
  }

  public func addInitialRepoContent() throws
  {
    let path = "file1.txt"

    try "some text".write(toFile: repository.fileURL(path).path,
                          atomically: true, encoding: .utf8)
    try repository.stage(file: path)
    try repository.index?.save()
    try repository.commit(message: "commit", amend: false)
  }

  public func makeRemoteRepo()
  {
    let parentPath = repoPath.deletingLastPathComponent

    remoteRepoPath = parentPath.appending(pathComponent: "remotetestrepo")
    remoteRepository = Self.createRepo(atPath: remoteRepoPath)
    XCTAssertNotNil(remoteRepository)
  }

  public func assertContent(_ text: String, file: String,
                            line: UInt = #line,
                            sourceFile: StaticString = #file)
  {
    do {
      let content = try String(contentsOfFile: repoPath +/ file,
                               encoding: .utf8)

      XCTAssertEqual(content, text, file: sourceFile, line: line)
    }
    catch let error {
      XCTFail(error.localizedDescription, file: sourceFile, line: line)
    }
  }

  public func assertContent<T: RawRepresentable>(_ text: String, file: T,
                                                 line: UInt = #line,
                                                 sourceFile: StaticString = #file)
    where T.RawValue == String
  {
    assertContent(text, file: file.rawValue, line: line, sourceFile: sourceFile)
  }

  public func assertStagedContent(_ text: String, file: String,
                                  line: UInt = #line,
                                  sourceFile: StaticString = #file) throws
  {
    guard let blob = repository.stagedBlob(file: file)
    else {
      XCTFail("could not get blob", file: sourceFile, line: line)
      return
    }
    let content = blob.withUnsafeBytes {
      String(bytes: $0, encoding: .utf8)
    }

    XCTAssertEqual(content, text, file: sourceFile, line: line)
  }

  public func assertStagedContent<T: RawRepresentable>(_ text: String, file: T,
                                                       line: UInt = #line,
                                                       sourceFile: StaticString = #file) throws
    where T.RawValue == String
  {
    try assertStagedContent(text, file: file.rawValue,
                            line: line, sourceFile: sourceFile)
  }

  public func makeStash() throws
  {
    try "stashy".write(toFile: repository.fileURL("file1.txt").path,
                       atomically: true, encoding: .utf8)
    try "new".write(toFile: repository.fileURL("untracked.txt").path,
                    atomically: true, encoding: .utf8)
    try "add".write(toFile: repository.fileURL("added.txt").path,
                    atomically: true, encoding: .utf8)
    try repository.stage(file: "added.txt")
    try repository.index?.save()
    try repository.saveStash(name: "", keepIndex: false,
                             includeUntracked: true, includeIgnored: true)
  }
}
#endif
