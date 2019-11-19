import XCTest

/// Tests that do not modify the repository, so it only needs to be set up once.
class ReadOnlyUITests: XCTestCase
{
  static var env: TestRepoEnvironment!

  override class func setUp()
  {
    env = TestRepoEnvironment(.testApp)!
  }
  
  override func setUp()
  {
    Self.env.open()
  }
  
  func testTitleBar()
  {
    let window = XitApp.windows.firstMatch
    let repoName = TestRepo.testApp.rawValue

    XCTAssertTrue(window.waitForExistence(timeout: 1.0))
    XCTAssertEqual(window.title, repoName)
    
    XCTAssertEqual(Window.titleLabel.value as? String, repoName)
    XCTAssertEqual(Window.branchPopup.value as? String, "master")
  }
    
  func testSidebar()
  {
    Sidebar.assertStagingStatus(workspace: 1, staged: 0)
    
    Sidebar.assertBranches(Self.env.repo.defaultBranches)
  }
  
  /// Tests filtering with no branch folders
  func testSidebarFilterFlat()
  {
    let aBranches = Self.env.repo.defaultBranches.filter { $0.contains("a") }
    let andBranches = aBranches.filter { $0.contains("and") }
    let masterBranchCell = Sidebar.list.cells["master"]
    let newBranchCell = Sidebar.list.cells["new"]
    let absent = NSPredicate(format: "exists == 0")
    
    Sidebar.filter.click()
    Sidebar.filter.typeText("a")
    wait(for: [expectation(for: absent, evaluatedWith: newBranchCell, handler: nil)],
         timeout: 2.0)
    
    Sidebar.assertBranches(aBranches)
    
    Sidebar.filter.typeText("nd")
    wait(for: [expectation(for: absent, evaluatedWith: masterBranchCell, handler: nil)],
         timeout: 2.0)

    Sidebar.assertBranches(andBranches)
    
    Sidebar.filter.buttons["cancel"].click()
    Thread.sleep(forTimeInterval: 0.5)

    Sidebar.assertBranches(Self.env.repo.defaultBranches)
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
