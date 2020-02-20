import AppKit
import XCTest

/// Shared code for setting up, opening, and operating on a test repository.
class TestRepoEnvironment
{
  let repo: TestRepo
  let tempDir = TemporaryDirectory("XitTest")
  let git: GitCLI
  let repoURL: URL
  
  init?(_ repo: TestRepo)
  {
    guard let tempURL = tempDir?.url,
          repo.extract(to: tempURL.path)
    else { return nil }
    
    self.repo = repo
    self.repoURL = tempURL.appendingPathComponent(repo.rawValue)
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
}
