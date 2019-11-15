import XCTest


class XitUITests: XCTestCase
{
  static let tempDir = TemporaryDirectory("XitTest")
  static var repoURL: URL!
  static var git: GitCLI!

  override class func setUp()
  {
    let repo = TestRepo.testApp
    guard let tempURL = tempDir?.url,
          repo.extract(to: tempURL.path)
    else {
      XCTFail()
      return
    }
    
    let repoURL = Self.tempDir!.url.appendingPathComponent(TestRepo.testApp.rawValue)

    git = GitCLI(repoURL: repoURL)
  }
  
  override func setUp()
  {
    XitApp.launchArguments = ["-noServices", "YES"]
    XitApp.launch()
    XitApp.activate()
    
    let repoURL = Self.tempDir!.url.appendingPathComponent(TestRepo.testApp.rawValue)
    
    NSWorkspace.shared.openFile(repoURL.path, withApplication: "Xit")
  }
  
  func testTitleBar()
  {
    let window = XitApp.windows.firstMatch
    let repoName = TestRepo.testApp.rawValue

    XCTAssertTrue(window.waitForExistence(timeout: 1.0))
    XCTAssertEqual(window.title, repoName)
    
    XCTAssertEqual(Window.titleLabel.value as? String, repoName)
    XCTAssertEqual(Window.branchPopup.value as? String, "master")
    
    // Try switching branches
    let otherBranch = "feature"
    
    Window.branchPopup.click()
    XitApp.menuItems[otherBranch].click()
    XCTAssertEqual(Window.branchPopup.value as? String, otherBranch)
    
    let currentBranch = Self.git.currentBranch()
    
    XCTAssertEqual(currentBranch, otherBranch)
  }
    
  func testSidebar()
  {
    Sidebar.assertStagingStatus(workspace: 1, staged: 0)
    
    Sidebar.assertBranches([
        "1-and_more", "and-how", "andhow-ad", "asdf", "blah", "feature",
        "hi!", "master", "new", "other-branch", "wat", "whateelse", "whup",
        ])
    
    // Rename a branch
    let oldBranchName = "and-how"
    let newBranchName = "and-then"

    Sidebar.list.staticTexts[oldBranchName].rightClick()
    XitApp.menuItems["Rename"].click()
    XitApp.typeText("\(newBranchName)\r")
    XCTAssertTrue(Sidebar.list.staticTexts[newBranchName].exists)

    // Verify the rename
    let branches = Self.git.branches()
    
    XCTAssertFalse(branches.contains(oldBranchName))
    XCTAssertTrue(branches.contains(newBranchName))
  }

  func testCommitContent()
  {
    CommitFileList.assertFiles(["README.md", "hero_slide1.png", "jquery-1.8.1.min.js"])
    
    CommitHeader.assertDisplay(date: "Jan 10, 2013 at 7:11 AM",
                               sha: "a4bca6b67a5483169963572ee3da563da33712f7",
                               name: "Danny Greg <danny@github.com>",
                               parents: ["Rename README."],
                               message: "Add 2 text and 1 binary file for diff tests.")
  }
  
  func testParents()
  {
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
