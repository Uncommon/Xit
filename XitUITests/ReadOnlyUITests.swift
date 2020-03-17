import XCTest

/// Tests that do not modify the repository, so it only needs to be set up once.
class ReadOnlyUITests: XCTestCase
{
  static var env: TestRepoEnvironment!

  override class func setUp()
  {
    env = TestRepoEnvironment(.testApp, testName: self.description())!
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
    
    Sidebar.filter.click()
    Sidebar.filter.typeText("a")
    wait(for: [absence(of: newBranchCell)], timeout: 2.0)
    
    Sidebar.assertBranches(aBranches)
    
    Sidebar.filter.typeText("nd")
    wait(for: [absence(of: masterBranchCell)], timeout: 2.0)

    Sidebar.assertBranches(andBranches)
    
    Sidebar.filter.buttons["cancel"].click()
    Thread.sleep(forTimeInterval: 0.5)

    Sidebar.assertBranches(Self.env.repo.defaultBranches)
  }

  /// Commit header and file list are correct
  func testCommitContent()
  {
    CommitFileList.assertFiles(["README.md", "hero_slide1.png", "jquery-1.8.1.min.js"])
    
    CommitHeader.assertDisplay(date: "Jan 10, 2013 at 7:11 AM",
                               sha: "a4bca6b67a5483169963572ee3da563da33712f7",
                               name: "Danny Greg <danny@github.com>",
                               parents: ["Rename README."],
                               message: "Add 2 text and 1 binary file for diff tests.")
  }
  
  /// Parents list is correct and can be clicked to navigate
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
  
  /// Status in window tab hides and shows in response to toggling the preference
  func testTabWorkspaceStatus()
  {
    PrefsWindow.open()
    if PrefsWindow.tabStatusCheck.value as? Int == 0 {
      PrefsWindow.tabStatusCheck.click()
    }
    
    XCTAssertTrue(Window.tabStatus.exists)
    
    PrefsWindow.tabStatusCheck.click()
    XCTAssertFalse(Window.tabStatus.exists)
    
    PrefsWindow.tabStatusCheck.click()
    XCTAssertTrue(Window.tabStatus.exists)
    PrefsWindow.close()
  }
  
  /// Copies the SHA of the clicked commit
  func testHistoryCopySHA()
  {
    HistoryList.row(1).rightClick()
    HistoryList.ContextMenu.copySHAItem.click()
    
    let pasteboard = NSPasteboard.general
    let copiedToxt = pasteboard.string(forType: .string)
    
    XCTAssertEqual(copiedToxt, "6b0c1c8b8816416089c534e474f4c692a76ac14f")
  }
  
  /// Reset should be disabled for the branch head
  func testResetEnabling()
  {
    let resetItem = HistoryList.ContextMenu.resetItem
    
    // For some reason row 0 is not hittable, but its cell is
    HistoryList.row(0).children(matching: .cell).element(boundBy: 0).rightClick()
    XCTAssertFalse(resetItem.isEnabled)
    XitApp.typeKey(.escape, modifierFlags: [])
    
    HistoryList.row(1).rightClick()
    XCTAssertTrue(resetItem.isEnabled)
    XitApp.typeKey(.escape, modifierFlags: [])
  }
  
  /// Reset mode description and status are updated when modes are selected
  func testResetSheet()
  {
    HistoryList.row(1).rightClick()
    HistoryList.ContextMenu.resetItem.click()
    
    XCTAssertTrue(ResetSheet.window.waitForExistence(timeout: 0.5))
    XCTAssertTrue(ResetSheet.mixedButton.intValue == 1)
    XCTAssertEqual(ResetSheet.modeDescription.stringValue,
                   """
                   Sets the current branch to point to the selected commit, and \
                   all staged changes are forgotten. Workspace files are not changed.
                   """)
    XCTAssertEqual(ResetSheet.statusText.stringValue,
                   "There are changes, but this option will preserve them.")
    
    ResetSheet.softButton.click()
    XCTAssertEqual(ResetSheet.modeDescription.stringValue,
                   """
                   Sets the current branch to point to the selected commit, but \
                   staged changes are retained and workspace files are not changed.
                   """)
    XCTAssertEqual(ResetSheet.statusText.stringValue,
                   "There are changes, but this option will preserve them.")

    ResetSheet.hardButton.click()
    XCTAssertEqual(ResetSheet.modeDescription.stringValue,
                   """
                   Clears all staged and workspace changes, and sets the current \
                   branch to point to the selected commit.
                   """)
    XCTAssertEqual(ResetSheet.statusText.stringValue,
                   "You have uncommitted changes that will be lost with this option.")
  }
}

extension XCUIElement
{
  var stringValue: String { value as? String ?? "" }
  var intValue: Int? { value as? Int }
}
