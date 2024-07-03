import XCTest

/// Tests that change the repository, and must therefore get a fresh copy of
/// the test repo for each run.
class ModifyingUITests: XCTestCase
{
  var env: TestRepoEnvironment!

  override func setUp()
  {
    guard let env = TestRepoEnvironment(.testApp, testName: name)
    else {
      XCTFail("Environment setup failed")
      continueAfterFailure = false
      return
    }
    
    self.env = env
  }

  func testCommitUI()
  {
    env.open()

    XCTAssert(Window.window.waitForExistence(timeout: 2))
    Sidebar.stagingCell.click()

    XCTContext.runActivity(named: "Initial empty state") {
      _ in
      XCTAssertEqual(StagedFileList.list.cells.count, 0,
                     "staged list should be empty")
      // In practice there should be one particular file, but for this test it
      // only matters that there is at least one.
      XCTAssert(WorkspaceFileList.list.cells.firstMatch.exists,
                "needs a file to stage")
      XCTAssertFalse(CommitEntry.commitButton.isEnabled,
                     "commit button should be disabled")
    }

    XCTContext.runActivity(named: "Commit message entered") {
      _ in
      CommitEntry.messageField.click()
      CommitEntry.messageField.typeText("message")

      XCTAssertFalse(CommitEntry.commitButton.isEnabled,
                     "commit button should be disabled with no staged files")
    }

    XCTContext.runActivity(named: "File staged") {
      _ in
      WorkspaceFileList.stage(item: 0)

      wait(for: [enabling(of: CommitEntry.commitButton)], timeout: 5.0)
    }

  }
  
  func testRenameBranch()
  {
    env.open()
    
    let oldBranchName = "and-how"
    let newBranchName = "and-then"

    Sidebar.list.staticTexts[oldBranchName].rightClick()
    XitApp.menuItems[.BranchPopup.rename].click()
    XitApp.typeText("\(newBranchName)\r")

    XCTAssertTrue(Sidebar.list.staticTexts[newBranchName]
        .waitForExistence(timeout: 1.0))

    let branches = env.git.branches()
    
    XCTAssertFalse(branches.contains(oldBranchName))
    XCTAssertTrue(branches.contains(newBranchName))
  }

  func testDeleteBranch()
  {
    env.open()

    let branchName = "and-how"
    let sheet = XitApp.sheets.firstMatch

    XCTAssert(Window.window.waitForExistence(timeout: 2))
    XCTContext.runActivity(named: "Cancel delete branch") {
      _ in
      Sidebar.list.staticTexts[branchName].rightClick()
      XitApp.menuItems[.BranchPopup.delete].click()

      XCTAssertTrue(sheet.exists)
      sheet.buttons["Cancel"].click()
      XCTAssertTrue(Sidebar.list.staticTexts[branchName].exists)
      XCTAssertTrue(env.git.branches().contains(branchName))
    }

    XCTContext.runActivity(named: "Actually delete branch") {
      _ in
      Sidebar.list.staticTexts[branchName].rightClick()
      XitApp.menuItems[.BranchPopup.delete].click()

      sheet.buttons["Delete"].click()
      wait(for: [absence(of: Sidebar.list.staticTexts[branchName])],
           timeout: 5.0)
      XCTAssertFalse(env.git.branches().contains(branchName))
    }
  }

  func testDeleteTag()
  {
    let tagName = "someTag"
    let sheet = XitApp.sheets.firstMatch

    // Add a tag because the test repo doesn't have any
    env.git.run(args: ["tag", tagName])
    env.open()

    XCTContext.runActivity(named: "Cancel delete tag") {
      _ in
      Sidebar.list.staticTexts[tagName].rightClick()
      XitApp.menuItems[.TagPopup.delete].click()

      XCTAssertTrue(sheet.exists)
      sheet.buttons["Cancel"].click()
      XCTAssertTrue(Sidebar.list.staticTexts[tagName].exists)
      XCTAssertTrue(env.git.tags().contains(tagName))
    }

    XCTContext.runActivity(named: "Actually delete tag") {
      _ in
      Sidebar.list.staticTexts[tagName].rightClick()
      XitApp.menuItems[.TagPopup.delete].click()

      sheet.buttons["Delete"].click()
      XCTAssertFalse(env.git.tags().contains(tagName))
      wait(for: [absence(of: Sidebar.list.staticTexts[tagName])],
           timeout: 5.0)
    }
  }

  func testSwitchBranch()
  {
    env.open()

    let branchText = Sidebar.currentBranchCell.staticTexts.firstMatch
    let featureBranch = "feature"

    XCTAssertEqual(branchText.stringValue, "master")

    env.git.checkOut(branch: featureBranch)

    wait(for: [expectation(for: .init(format: "value == %@", featureBranch),
                          evaluatedWith: branchText)],
         timeout: 5)
  }
  
  func testTitleBarBranchSwitch()
  {
    env.open()
    
    let otherBranch = "feature"
    
    Window.branchPopup.click()
    XitApp.menuItems[otherBranch].click()
    wait(for: [expectation(for: .init(format: "value == '\(otherBranch)'"),
                           evaluatedWith: Window.branchPopup)],
         timeout: 2)
    
    let currentBranch = env.git.currentBranch()
    
    XCTAssertEqual(currentBranch, otherBranch)
  }
  
  func testFilterBranchFolder()
  {
    let folderName = "folder"
    let subBranchName = "and-why"
    
    env.git.run(args: ["branch", "\(folderName)/\(subBranchName)"])
    env.open()
    
    let newBranchCell = Sidebar.cell(named: "new")

    XCTAssertTrue(newBranchCell.waitForExistence(timeout: 1))
    
    Sidebar.filter.click()
    Sidebar.filter.typeText("a")
    wait(for: [absence(of: newBranchCell)], timeout: 5.0)

    // Expand the folder
    Sidebar.list.children(matching: .outlineRow).element(boundBy: 9)
           .disclosureTriangles.firstMatch.click()

    let folderCell = Sidebar.cell(named: folderName)
    let subBranchCell = Sidebar.cell(named: subBranchName)
    
    XCTAssertTrue(folderCell.exists)
    XCTAssertTrue(subBranchCell.waitForExistence(timeout: 1.0))

    Sidebar.filter.typeText("s")
    
    wait(for: [absence(of: folderCell)], timeout: 5.0)
    XCTAssertFalse(subBranchCell.exists)
  }
  
  func reset(modeButton: XCUIElement)
  {
    XCTContext.runActivity(named: "Resetting") { _ in
      env.write("some stuff", to: "README1.txt")
      env.write("other stuff", to: "REAME_")
      env.git.run(args: ["add", "REAME_"])
      
      HistoryList.row(2).rightClick()
      HistoryList.ContextMenu.resetItem.click()
      XCTAssertTrue(ResetSheet.window.waitForExistence(timeout: 0.5))
      modeButton.click()
      ResetSheet.resetButton.click()
    }
  }
  
  func testResetSoft()
  {
    env.open()
    
    reset(modeButton: ResetSheet.softButton)
    Sidebar.stagingCell.click()

    // Temporary workaround
    StagedFileList.refreshButton.click()
    
    XCTAssertTrue(StagedFileList.list.outlineRows.element(boundBy: 3)
                                .waitForExistence(timeout: 1.0),
                  "list did not update")
    
    // Files added in the old HEAD are now staged, plus the file that was
    // explicitly staged before the reset
    StagedFileList.assertFiles(["README.md", "REAME_", "hero_slide1.png", "jquery-1.8.1.min.js"])
    WorkspaceFileList.assertFiles(["README1.txt", "UntrackedImage.png"])
  }
  
  func testResetMixed()
  {
    env.open()
    
    reset(modeButton: ResetSheet.mixedButton)
    Sidebar.stagingCell.click()

    // Temporary workaround
    StagedFileList.refreshButton.click()

    StagedFileList.assertFiles([])
    WorkspaceFileList.assertFiles(["README.md", "README1.txt", "REAME_",
                                   "UntrackedImage.png", "hero_slide1.png",
                                   "jquery-1.8.1.min.js"])
  }
  
  func testResetHard()
  {
    env.open()
    
    reset(modeButton: ResetSheet.hardButton)
    Sidebar.stagingCell.click()
    
    // Temporary workaround
    StagedFileList.refreshButton.click()

    StagedFileList.assertFiles([])
    // Untracked files survive a hard reset
    WorkspaceFileList.assertFiles(["UntrackedImage.png"])
  }
  
  func modifyAndStage(file: String, text: String)
  {
    env.write(text, to: file)
    env.git.run(args: ["add", file])
  }
  
  func testFilterComments()
  {
    let enteredText = """
          First line
          # comment line
          Second line
          """
    let expectedText = """
          First line
          Second line
          """
    
    modifyAndStage(file: "README1.txt", text: "some stuff")

    env.open()
    
    Sidebar.stagingCell.click()
    if (CommitEntry.stripCheck.value as? Int) == 0 {
      CommitEntry.stripCheck.click()
    }
    CommitEntry.messageField.click()
    CommitEntry.messageField.typeText(enteredText)
    CommitEntry.commitButton.click()
    HistoryList.row("First line ⋯").click()
    XCTAssertEqual(CommitHeader.messageField.stringValue, expectedText)
  }
  
  func testDontFilterComments()
  {
    let enteredText = """
          First line
          # comment line
          Second line
          """

    modifyAndStage(file: "README1.txt", text: "some stuff")

    env.open()
    
    Sidebar.stagingCell.click()
    if (CommitEntry.stripCheck.value as? Int) != 0 {
      CommitEntry.stripCheck.click()
    }
    CommitEntry.messageField.click()
    CommitEntry.messageField.typeText(enteredText)
    CommitEntry.commitButton.click()
    HistoryList.row("First line ⋯").click()
    XCTAssertEqual(CommitHeader.messageField.stringValue, enteredText)
  }

  func testClean()
  {
    env.open()

    Toolbar.clean.click()
    CleanSheet.fileMode.click()
    CleanSheet.FileMode.ignored.click()

    XCTContext.runActivity(named: "Clean selected") { _ in
      let firstIgnoredURL = env.repoURL.appendingPathComponent(".DS_Store")

      XCTAssertTrue(FileManager.default.fileExists(atPath: firstIgnoredURL.path))

      CleanSheet.window.cells.firstMatch.click()
      CleanSheet.cleanSelectedButton.click()
      XitApp.sheets.buttons["Delete"].click()

      XCTAssertFalse(FileManager.default.fileExists(atPath: firstIgnoredURL.path))
      CleanSheet.assertCleanFiles(["joshaber.pbxuser", "joshaber.perspectivev3"])
      XCTAssertTrue(CleanSheet.window.cells.firstMatch.isEnabled)
      XCTAssertTrue(CleanSheet.cleanSelectedButton.isEnabled)
    }

    XCTContext.runActivity(named: "Clean all") { _ in
      CleanSheet.cleanAllButton.click()
      XitApp.sheets.buttons["Delete"].click()

      CleanSheet.assertCleanFiles([])
      XCTAssertFalse(CleanSheet.cleanAllButton.isEnabled)
    }
  }

  func testRenameFile() throws
  {
    env.open()

    let oldName = "README1.txt"
    let newName = "RENAMED.txt"
    let oldURL = env.repoURL.appendingPathComponent(oldName)
    let newURL = env.repoURL.appendingPathComponent(newName)

    try XCTContext.runActivity(named: "Rename") { _ in
      try FileManager.default.moveItem(at: oldURL, to: newURL)

      Sidebar.stagingCell.click()
      StagedFileList.assertFiles([])
      WorkspaceFileList.assertFiles([newName, "UntrackedImage.png"])
    }

    XCTContext.runActivity(named: "Stage") { _ in
      WorkspaceFileList.stage(item: 0)

      Thread.sleep(forTimeInterval: 0.5)
      StagedFileList.assertFiles([newName])
      WorkspaceFileList.assertFiles(["UntrackedImage.png"])
    }

    XCTContext.runActivity(named: "Unstage") { _ in
      StagedFileList.unstage(item: 0)

      Thread.sleep(forTimeInterval: 0.5)
      StagedFileList.assertFiles([])
      WorkspaceFileList.assertFiles([newName, "UntrackedImage.png"])
    }
  }
}
