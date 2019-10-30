import XCTest
//@testable import Xit

class TemporaryDirectory
{
  let url: URL
  
  init?(_ name: String, clearFirst: Bool = true)
  {
    let manager = FileManager.default
    
    self.url = manager.temporaryDirectory
                      .appendingPathComponent(name, isDirectory: true)
    do {
      if clearFirst && manager.fileExists(atPath: url.path) {
        try manager.removeItem(at: url)
      }
      try manager.createDirectory(at: url,
                                  withIntermediateDirectories: true,
                                  attributes: nil)
    }
    catch {
      return nil
    }
  }
  
  deinit
  {
    try? FileManager.default.removeItem(at: url)
  }
}

class XitUITests: XCTestCase
{
  enum TestRepo: String
  {
    case conflicted = "conflicted-repo"
    case submodule = "repo-with-submodule"
    case testApp = "Test_App"
    case testAppFork = "Test_App_fork"
    case unicode = "unicode-files-repo"
  }
  
  static func extractTestRepo(_ repo: TestRepo, to targetPath: String) -> Bool
  {
    let bundle = Bundle(identifier: "com.uncommonplace.XitUITests")!
    let fixturesURL = bundle.url(forResource: "fixtures",
                                 withExtension: "zip")!
    let unzipTask = Process()
    
    unzipTask.launchPath = "/usr/bin/unzip"
    unzipTask.arguments = [fixturesURL.path, repo.rawValue + "/*"]
    unzipTask.currentDirectoryPath = targetPath
    
    NSLog("unzipping \(repo.rawValue) to \(targetPath)")
    unzipTask.launch()
    unzipTask.waitUntilExit()
    
    guard unzipTask.terminationStatus == 0
    else {
      XCTFail("unzip failed")
      return false
    }
    return true
  }
  
  let tempDir = TemporaryDirectory("XitTest")
  
  override func setUp()
  {
    guard let tempURL = tempDir?.url,
          XitUITests.extractTestRepo(.testApp, to: tempURL.path)
    else { XCTFail(); return }
    
  }
  
  override func tearDown()
  {
    NSDocumentController.shared.closeAllDocuments(withDelegate: nil,
                                                  didCloseAllSelector: nil,
                                                  contextInfo: nil)
  }
  
  func testRepoWindow()
  {
    guard testRun?.hasSucceeded ?? false else { return }
    let app = XCUIApplication(bundleIdentifier: "com.uncommonplace.Xit")
    
    app.launchArguments = ["-noServices", "YES"]
    app.launch()
    
    let repoName = TestRepo.testApp.rawValue
    let repoURL = tempDir!.url.appendingPathComponent(repoName)
    
    NSDocumentController.shared.openDocument(withContentsOf: repoURL,
                                             display: true) { _,_,_ in }
    
    let window = app.windows.firstMatch
    
    XCTAssertTrue(window.waitForExistence(timeout: 1.0))
    XCTAssertEqual(window.title, repoName)
    
    // check the window contents
  }
}
