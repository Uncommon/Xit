import XCTest

/// Tests that do not modify the repository, so it only needs to be set up once.
class ReadOnlyUITests: XCTestCase
{
  static var env: TestRepoEnvironment!

  override class func setUp()
  {
    env = TestRepoEnvironment(.testApp, testName: self.description())
  }
  
  override func setUpWithError() throws
  {
    if Self.env == nil {
      // Error should have been logged in setUp()
      throw XCTSkip()
    }
    Self.env.open()
  }
  
  func testTitleBar()
  {
    let window = XitApp.windows.firstMatch
    let repoName = TestRepo.testApp.rawValue

    XCTAssertTrue(window.waitForExistence(timeout: 1.0))
    XCTAssertEqual(window.title, repoName)
    
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
    let masterBranchCell = Sidebar.cell(named: "master")
    let newBranchCell = Sidebar.cell(named: "new")
    
    XCTContext.runActivity(named: "Filter with 'a'") { _ in
      Sidebar.filter.click()
      Sidebar.filter.typeText("a")
      wait(for: [absence(of: newBranchCell)], timeout: 5.0)
      
      Sidebar.assertBranches(aBranches)
    }
    
    XCTContext.runActivity(named: "Filter with 'and'") { _ in
      Sidebar.filter.typeText("nd")
      wait(for: [absence(of: masterBranchCell)], timeout: 5.0)

      Sidebar.assertBranches(andBranches)
    }
    
    XCTContext.runActivity(named: "Clear filter") { _ in
      Sidebar.filter.buttons["cancel"].click()
      wait(for: [presence(of: newBranchCell)], timeout: 8.0)

      Sidebar.assertBranches(Self.env.repo.defaultBranches)
    }
  }

  /// Commit header and file list are correct
  func testCommitContent()
  {
    XCTWaiter(delegate: self).wait(for: [presence(of: CommitFileList.list.outlineRows.firstMatch)],
                                   timeout: 5)
    CommitFileList.assertFiles(["README.md", "hero_slide1.png", "jquery-1.8.1.min.js"])
    
    let sha = "a4bca6b67a5483169963572ee3da563da33712f7"
    let shaPrefix = String(sha.prefix(6))
    
    CommitHeader.assertDisplay(date: "Jan 10, 2013 at 7:11 AM",
                               sha: shaPrefix,
                               name: "Danny Greg",
                               email: "<danny@github.com>",
                               parents: ["Rename README."],
                               message: "Add 2 text and 1 binary file for diff tests.")
  }
  
  /// Parents list is correct and can be clicked to navigate
  func testParents()
  {
    // Select a merge commit to test multiple parents
    HistoryList.row(10).click()
    
    let sha = "d603d61ea756eb881ba440b3e66b561d070aec6e"
    let shaPrefix = String(sha.prefix(6))
    
    CommitHeader.assertDisplay(date: "Feb 16, 2012 at 12:10 PM",
                               sha: shaPrefix,
                               name: "joshaber",
                               email: "<joshaber@gmail.com>",
                               parents: ["Revert ee618c62f57e7807ddee3cd33e0f176d93d015dd^..HEAD",
                                         "evil conflicting commit"],
                               message: "Merge branch 'master' of github.com:github/Test_App")
    
    // Navigate by clicking a parent title
    CommitHeader.parentField(0).click()
    
    XCTAssertTrue(HistoryList.row(13).isSelected)
  }
  
  func ensureTabBarVisible()
  {
    let menuBar = XitApp.menuBars
    let viewMenu = menuBar.menuBarItems["View"]
    let menuItem = viewMenu.menuItems["Show Tab Bar"]
    
    viewMenu.click()
    if (menuItem.exists) {
      menuItem.click()
    }
    else {
      XitApp.typeKey(.escape, modifierFlags: [])
    }
  }
  
  /// Status in window tab hides and shows in response to toggling the preference
  func testTabWorkspaceStatus()
  {
    ensureTabBarVisible()
    
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
    
    XCTContext.runActivity(named: "Disabled for current commit") { _ in
      // For some reason row 0 is not hittable, but its cell is
      HistoryList.row(0).children(matching: .cell).element(boundBy: 0).rightClick()
      XCTAssertFalse(resetItem.isEnabled)
      XitApp.typeKey(.escape, modifierFlags: [])
    }
    
    XCTContext.runActivity(named: "Enabled for other commit") { _ in
      HistoryList.row(1).rightClick()
      XCTAssertTrue(resetItem.isEnabled)
      XitApp.typeKey(.escape, modifierFlags: [])
    }
  }
  
  /// Reset mode description and status are updated when modes are selected
  func testResetSheet()
  {
    HistoryList.row(1).rightClick()
    HistoryList.ContextMenu.resetItem.click()
    
    XCTAssertTrue(ResetSheet.window.waitForExistence(timeout: 0.5))

    XCTContext.runActivity(named: "Mixed mode") { _ in
      XCTAssertTrue(ResetSheet.mixedButton.intValue == 1)
      XCTAssertEqual(ResetSheet.modeDescription.stringValue,
                     """
                     Sets the current branch to point to the selected commit, and \
                     all staged changes are forgotten. Workspace files are not changed.
                     """)
      XCTAssertEqual(ResetSheet.statusText.stringValue,
                     "There are changes, but this option will preserve them.")
    }

    XCTContext.runActivity(named: "Soft mode") { _ in
      ResetSheet.softButton.click()
      XCTAssertEqual(ResetSheet.modeDescription.stringValue,
                     """
                     Sets the current branch to point to the selected commit, but \
                     staged changes are retained and workspace files are not changed.
                     """)
      XCTAssertEqual(ResetSheet.statusText.stringValue,
                     "There are changes, but this option will preserve them.")
    }

    XCTContext.runActivity(named: "Hard mode") { _ in
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
  
  func checkPopup(_ context: String,
                  button: XCUIElement, menu: XCUIElement, itemTitles: [String],
                  file: StaticString = #file, line: UInt = #line)
  {
    XCTContext.runActivity(named: context) { _ in
      button.press(forDuration: 0.25)

      XCTAssertTrue(menu.isHittable)
      XCTAssertEqual(menu.menuItems.count, itemTitles.count,
                     "wrong number of items", file: file, line: line)

      for (index, title) in itemTitles.enumerated() {
        XCTAssertEqual(menu.menuItems.element(boundBy: index).title, title,
                       file: file, line: line)
      }
      XitApp.typeKey(.escape, modifierFlags: [])
    }
  }
  
  func testRepoOpMenus() throws
  {
    checkPopup("Fetch menu",
               button: Window.fetchButton, menu: Window.fetchMenu, itemTitles: [
      "Fetch All Remotes",
      "Fetch \"origin/master\"",
      "",
      "Fetch Remote \"origin\"",
    ])
    
    checkPopup("Push menu",
               button: Window.pushButton, menu: Window.pushMenu, itemTitles: [
      "Push to \"origin/master\"",
      "",
      "Push to Any Tracking Branches on \"origin\"",
    ])
    
    checkPopup("Pull menu",
               button: Window.pullButton, menu: Window.pullMenu, itemTitles: [
      "Pull from \"origin/master\""
    ])
  }

  func testClean() throws
  {
    Toolbar.clean.click()

    let cell1 = CleanSheet.window.cells.firstMatch

    XCTContext.runActivity(named: "Initial state") { _ in
      XCTAssertEqual(CleanSheet.folderMode.stringValue, "Ignore")
      XCTAssertFalse(CleanSheet.cleanSelectedButton.isEnabled)
      CleanSheet.assertCleanFiles(["UntrackedImage.png"])
    }

    XCTContext.runActivity(named: "Cell selected") { _ in
      cell1.click()

      XCTAssertTrue(CleanSheet.cleanSelectedButton.isEnabled)
    }

    XCTContext.runActivity(named: "Ignored mode") { _ in
      CleanSheet.fileMode.click()
      CleanSheet.FileMode.ignored.click()

      CleanSheet.assertCleanFiles(
          [".DS_Store", "joshaber.pbxuser", "joshaber.perspectivev3"])
    }

    let allFiles = [".DS_Store", "joshaber.pbxuser", "joshaber.perspectivev3",
                    "UntrackedImage.png"]

    XCTContext.runActivity(named: "All files mode") { _ in
      CleanSheet.fileMode.click()
      CleanSheet.FileMode.all.click()

      CleanSheet.assertCleanFiles(allFiles)
    }

    // Because .DS_Store is first in the list, clean should fail without
    // deleting any files, so the repo should remain unmodified.
    try XCTContext.runActivity(named: "Attempt to clean locked file") { _ in
      let url = Self.env.repoURL.appendingPathComponent(".DS_Store")

      XCTAssertNoThrow(try FileManager.default
          .setAttributes([.immutable: NSNumber(booleanLiteral: true)],
                         ofItemAtPath: url.path))
      addTeardownBlock {
        try? FileManager.default
          .setAttributes([.immutable: NSNumber(booleanLiteral: false)],
                         ofItemAtPath: url.path)
      }
      cell1.click()
      CleanSheet.cleanSelectedButton.click()
      XitApp.sheets.buttons["Delete"].click() // confirmation
      XitApp.sheets.buttons["OK"].click() // locked file error

      CleanSheet.cleanAllButton.click()
      XitApp.sheets.buttons["Delete"].click()
      XitApp.sheets.buttons["OK"].click()

      CleanSheet.refreshButton.click()
      CleanSheet.assertCleanFiles(allFiles)
    }
  }

  func testSearch()
  {
    Toolbar.search.click()
    XCTContext.runActivity(named: "Search by summary") {
      _ in
      Search.field.click()
      Search.field.typeText("asd")
      Search.searchDown.click()
      XCTAssert(HistoryList.row(2).isSelected)
      Search.searchDown.click()
      XCTAssert(HistoryList.row(27).isSelected)
      Search.searchUp.click()
      XCTAssert(HistoryList.row(2).isSelected)
    }
    XCTContext.runActivity(named: "Search by SHA") {
      _ in
      Search.setSearchType(.sha)
      Search.clearButton.click()
      Search.field.typeText("93f5")
      Search.field.typeKey(.return, modifierFlags: [])
      XCTAssert(HistoryList.row(4).isSelected)
    }
    XCTContext.runActivity(named: "Search by author") {
      _ in
      Search.setSearchType(.author)
      Search.clearButton.click()
      Search.field.typeText("Danny")
      Search.searchUp.click()
      XCTAssert(HistoryList.row(1).isSelected)
    }
  }
}

extension XCUIElement
{
  var stringValue: String { value as? String ?? "" }
  var intValue: Int? { value as? Int }
}
