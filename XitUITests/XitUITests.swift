import XCTest


class XitUITests: XCTestCase
{
  let tempDir = TemporaryDirectory("XitTest")
  let app = XCUIApplication(bundleIdentifier: "com.uncommonplace.Xit")
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
    
    Sidebar.assertStagingStatus(workspace: 1, staged: 0)
    
    Sidebar.assertBranches([
        "1-and_more", "and-how", "andhow-ad", "asdf", "blah", "feature",
        "hi!", "master", "new", "other-branch", "wat", "whateelse", "whup",
        ])

    CommitFileList.assertFiles(["README.md", "hero_slide1.png", "jquery-1.8.1.min.js"])
    
    CommitHeader.assertDisplay(date: "Jan 10, 2013 at 7:11 AM",
                               sha: "a4bca6b67a5483169963572ee3da563da33712f7",
                               name: "Danny Greg <danny@github.com>",
                               parents: ["Rename README."],
                               message: "Add 2 text and 1 binary file for diff tests.")

    // Select a merge commit to test multiple parents
    HistoryList.row(10).click()
    
    CommitHeader.assertDisplay(date: "Feb 16, 2012 at 12:10 PM",
                               sha: "d603d61ea756eb881ba440b3e66b561d070aec6e",
                               name: "joshaber <joshaber@gmail.com>",
                               parents: ["Revert ee618c62f57e7807ddee3cd33e0f176d93d015dd^..HEAD",
                                         "evil conflicting commit"],
                               message: "Merge branch 'master' of github.com:github/Test_App")
    
    // Navigate by clicking a parent title
    CommitHeader.parentField(0).click()
    
    XCTAssertTrue(HistoryList.row(13).isSelected)
  }
}

extension XCUIElement
{
  var stringValue: String { value as? String ?? "" }
}
