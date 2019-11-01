import XCTest


class XitUITests: XCTestCase
{
  let tempDir = TemporaryDirectory("XitTest")
  var repoURL: URL!
  
  override func setUp()
  {
    let repo = TestRepo.testApp
    guard let repoURL = tempDir?.url,
          repo.extract(to: repoURL.path)
    else {
      XCTFail()
      return
    }
    
    self.repoURL = repoURL.appendingPathComponent(repo.rawValue)
  }
  
  override func tearDown()
  {
    NSDocumentController.shared.closeAllDocuments(withDelegate: nil,
                                                  didCloseAllSelector: nil,
                                                  contextInfo: nil)
  }
  
  func testRepoWindow()
  {
    guard repoURL != nil else { return }
    let app = XCUIApplication(bundleIdentifier: "com.uncommonplace.Xit")
    
    app.launchArguments = ["-noServices", "YES"]
    app.launch()
    app.activate()
    
    let repoName = TestRepo.testApp.rawValue
    
    NSWorkspace.shared.openFile(repoURL.path, withApplication: "Xit")
    
    let window = app.windows.firstMatch
    
    XCTAssertTrue(window.waitForExistence(timeout: 1.0))
    XCTAssertEqual(window.title, repoName)
    
    let titleView = window.staticTexts.matching(identifier: "titleLabel").firstMatch
    let branchPopup = window.popUpButtons.matching(identifier: "branchPopup").firstMatch

    XCTAssertEqual(titleView.value as? String, repoName)
    XCTAssertEqual(branchPopup.value as? String, "master")
    
    // staging has 1 > 0
    
    let branches = [
      "1-and_more",
      "and-how",
      "andhow-ad",
      "asdf",
      "blah",
      "feature",
      "hi!",
      "master",
      "new",
      "other-branch",
      "wat",
      "whateelse",
      "whup",
    ]
    let sidebar = app.outlines["sidebar"]

    for (index, branch) in branches.enumerated() {
      let cell = sidebar.cells.element(boundBy: index + 3)
      let label = cell.staticTexts.firstMatch.value as? String
      
      XCTAssertEqual(label, branch)
    }
  }
}
