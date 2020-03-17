import AppKit
import XCTest

/// Shared code for setting up, opening, and operating on a test repository.
class TestRepoEnvironment
{
  let repo: TestRepo
  let tempDir: TemporaryDirectory
  let git: GitCLI
  let repoURL: URL
  
  init?(_ repo: TestRepo, testName: String)
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
  }
  
  func open()
  {
    XitApp.launchArguments = ["-noServices", "YES",
                              "-ApplePersistenceIgnoreState", "YES"]
    XitApp.launch()
    XitApp.activate()
    
    // Unfortunately XCUIApplication.path is undocumented but there seems to
    // be no other way at it. We need to make sure NSWorkspace doesn't launch
    // a new instance.
    let appURL = URL(fileURLWithPath: XitApp.value(forKey: "path") as! String)
    
    NSWorkspace.shared.open([repoURL], withApplicationAt: appURL,
                            configuration: .init(), completionHandler: nil)
    XCTAssertTrue(XitApp.windows[repo.rawValue].waitForExistence(timeout: 5.0))
  }
  
  func write(_ text: String, to path: String,
             file: StaticString = #file,
             line: UInt = #line)
  {
    let fileURL = repoURL.appendingPathComponent(path)
    
    XCTAssertNoThrow(try text.write(to: fileURL, atomically: true, encoding: .utf8),
                     file: file, line: line)
  }
}
