import AppKit
import XCTest

class TestXitEnvironment
{
  // Like the one in the app Testing enum, but there is no `standard` case
  enum Defaults: String
  {
    case tempEmpty, tempAccounts
  }

  let defaults: Defaults

  init(defaults: Defaults = .tempEmpty)
  {
    self.defaults = defaults
  }

  /// Launches the app and opens this environment's repository.
  func open(args: [String] = [])
  {
    XitApp.launchArguments = args +
                            ["-ApplePersistenceIgnoreState", "YES",
                              "--defaults", "\(defaults)"]
    XitApp.launch()
    XitApp.activate()
  }
}

/// Shared code for setting up, opening, and operating on a test repository.
class TestRepoEnvironment: TestXitEnvironment
{
  let repo: TestRepo
  let tempDir: TemporaryDirectory
  let git: GitCLI
  let repoURL: URL
  private(set) var remotePath: String!
  private(set) var remoteGit: GitCLI! = nil
  private(set) var remoteURL: URL! = nil

  init?(_ repo: TestRepo, testName: String, defaults: Defaults = .tempEmpty)
  {
    guard let tempDir = TemporaryDirectory(testName)
    else {
      XCTFail("Failed to get temp directory")
      return nil
    }

    guard repo.extract(to: tempDir.url.path)
    else {
      XCTFail("Repository failed to extract")
      return nil
    }
    
    self.tempDir = tempDir
    self.repo = repo
    self.repoURL = tempDir.url.appendingPathComponent(repo.rawValue)
    self.git = GitCLI(repoURL: repoURL)

    super.init(defaults: .tempEmpty)
  }
  
  /// Extracts the test repo again, to another location, and sets it as
  /// a remote of the main repository.
  func makeRemoteCopy(named remoteName: String) -> Bool
  {
    let remoteParent = tempDir.url.path + ".origin"
    
    remotePath = remoteParent.appending(pathComponent: repo.rawValue)
    try? FileManager.default.createDirectory(atPath: remotePath,
                                             withIntermediateDirectories: true,
                                             attributes: nil)
    remoteURL = URL(fileURLWithPath: remotePath)
    
    guard repo.extract(to: remoteParent)
    else {
      XCTFail("Failed to make remote")
      return false
    }
    
    git.run(args: ["remote", "add", "-f", remoteName, remotePath])
    remoteGit = GitCLI(repoURL: remoteURL)
    
    return true
  }
  
  /// Clones the main repository as a bare repository, and adds that as a remote.
  func makeBareRemote(named remoteName: String) -> Bool
  {
    let remoteParent = tempDir.url.path + ".origin"
    
    remotePath = remoteParent +/ repo.rawValue + ".git"
    do {
      if FileManager.default.fileExists(atPath: remotePath) {
        try FileManager.default.removeItem(atPath: remotePath)
      }
      try FileManager.default.createDirectory(atPath: remotePath,
                                              withIntermediateDirectories: true,
                                              attributes: nil)
    }
    catch let error as NSError {
      XCTFail("Could not create parent directory: \(error.description)")
      return false
    }
    remoteURL = URL(fileURLWithPath: remotePath)
    
    // A special git runner is needed so it has the right working directory
    let cloneRunner = GitCLI(repoURL: URL(fileURLWithPath: remoteParent,
                                          isDirectory: true))

    cloneRunner.run(args: ["clone", "--bare", git.runner.workingDir])
    git.run(args: ["remote", "add", "-f", remoteName, remotePath])
    remoteGit = GitCLI(repoURL: remoteURL)

    return true
  }
  
  /// Launches the app and opens this environment's repository.
  override func open(args: [String] = [])
  {
    open(args: [repoURL.path] + args)

    XCTAssertTrue(XitApp.windows[repo.rawValue].waitForExistence(timeout: 5.0))
  }
  
  func write(_ text: String, to path: String,
             file: StaticString = #file,
             line: UInt = #line)
  {
    let fileURL = repoURL.appendingPathComponent(path)
    
    XCTAssertNoThrow(try text.write(to: fileURL, atomically: true,
                                    encoding: .utf8),
                     file: file, line: line)
  }
  
  func writeRemote(_ text: String, to path: String,
                   file: StaticString = #file,
                   line: UInt = #line)
  {
    let fileURL = remoteURL.appendingPathComponent(path)
    
    XCTAssertNoThrow(try text.write(to: fileURL, atomically: true,
                                    encoding: .utf8),
                     file: file, line: line)
  }
}
