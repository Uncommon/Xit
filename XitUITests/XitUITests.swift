import XCTest


class XitUITests: XCTestCase
{
  let tempDir = TemporaryDirectory("XitTest")
  
  override func setUp()
  {
    guard let tempURL = tempDir?.url,
          TestRepo.testApp.extract(to: tempURL.path)
    else {
      XCTFail()
      return
    }
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
