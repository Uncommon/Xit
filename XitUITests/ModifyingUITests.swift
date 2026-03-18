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
    BranchList.stagingCell.click()

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
  
  func testRenameBranch() throws
  {
    env.open()
    
    let oldBranchName = "and-how"
    let newBranchName = "and-then"

    Sidebar.Branches.list.staticTexts[oldBranchName].rightClick()
    Window.window.menuItems[.BranchPopup.rename].click()
    XitApp.typeText("\(newBranchName)\r")

    XCTAssertTrue(Sidebar.Branches.list.staticTexts[newBranchName]
        .waitForExistence(timeout: 1.0))

    let branches = try env.git.branches()

    XCTAssertFalse(branches.contains(oldBranchName))
    XCTAssertTrue(branches.contains(newBranchName))
  }

  func testDeleteBranch() throws
  {
    env.open()

    let branchName = "and-how"
    let sheet = XitApp.sheets.firstMatch

    XCTAssert(Window.window.waitForExistence(timeout: 2))
    try XCTContext.runActivity(named: "Cancel delete branch") {
      _ in
      Sidebar.Branches.list.staticTexts[branchName].rightClick()
      Window.window.menuItems[.BranchPopup.delete].click()

      XCTAssertTrue(sheet.exists)
      sheet.buttons["Cancel"].click()
      XCTAssertTrue(Sidebar.Branches.list.staticTexts[branchName].exists)
      XCTAssertTrue(try env.git.branches().contains(branchName))
    }

    try XCTContext.runActivity(named: "Actually delete branch") {
      _ in
      Sidebar.Branches.list.staticTexts[branchName].rightClick()
      Window.window.menuItems[.BranchPopup.delete].click()

      sheet.buttons["Delete"].click()
      wait(for: [absence(of: Sidebar.Branches.list.staticTexts[branchName])],
           timeout: 5.0)
      XCTAssertFalse(try env.git.branches().contains(branchName))
    }
  }

  func testDeleteTag() throws
  {
    let tagName = "someTag"
    let sheet = XitApp.sheets.firstMatch
    // Menu item identifier isn't getting set, unlike in the branch list
    let deleteItem = XitApp.windows.menuItems["Delete"]
    let tagCell = Sidebar.Tags.cell(named: tagName)

    // Add a tag because the test repo doesn't have any
    try env.git.run(args: ["tag", tagName])
    env.open()

    Sidebar.Tab.tags.click()

    try XCTContext.runActivity(named: "Cancel delete tag") {
      _ in
      tagCell.rightClick()
      deleteItem.click()

      XCTAssertTrue(sheet.exists)
      sheet.buttons["Cancel"].click()
      XCTAssertTrue(tagCell.exists)
      XCTAssertTrue(try env.git.tags().contains(tagName))
    }

    try XCTContext.runActivity(named: "Actually delete tag") {
      _ in
      tagCell.rightClick()
      deleteItem.click()

      sheet.buttons["Delete"].click()
      XCTAssertFalse(try env.git.tags().contains(tagName))
      wait(for: [absence(of: tagCell)], timeout: 5.0)
    }
  }

  func testSwitchBranch() throws
  {
    env.open()

    let branchText = Sidebar.Branches.currentBranchCell.staticTexts.firstMatch
    let featureBranch = "feature"

    XCTAssertEqual(branchText.stringValue, "master")

    try env.git.checkOut(branch: featureBranch)

    wait(for: [expectation(for: .init(format: "value == %@", featureBranch),
                           evaluatedWith: branchText)],
         timeout: 5)
  }
  
  func testTitleBarBranchSwitch() throws
  {
    env.open()
    
    let otherBranch = "feature"
    
    Window.branchPopup.click()
    XitApp.menuItems[otherBranch].click()
    wait(for: [expectation(for: .init(format: "value == '\(otherBranch)'"),
                           evaluatedWith: Window.branchPopup)],
         timeout: 2)
    
    let currentBranch = try env.git.currentBranch()

    XCTAssertEqual(currentBranch, otherBranch)
  }
  
  func testFilterBranchFolder() throws
  {
    let folderName = "folder"
    let subBranchName = "and-why"
    
    try env.git.run(args: ["branch", "\(folderName)/\(subBranchName)"])
    env.open()
    
    let newBranchCell = Sidebar.Branches.cell(named: "new")

    XCTAssertTrue(newBranchCell.waitForExistence(timeout: 1))
    
    Sidebar.Branches.filterField.click()
    Sidebar.Branches.filterField.typeText("a")
    wait(for: [absence(of: newBranchCell)], timeout: 5.0)

    // Expand the folder
    Sidebar.Branches.list.disclosureTriangles.firstMatch.click()

    let subBranchCell = Sidebar.Branches.cell(named: subBranchName)

    XCTAssertTrue(subBranchCell.waitForExistence(timeout: 1.0))

    Sidebar.Branches.filterField.typeText("s")

    wait(for: [absence(of: subBranchCell)], timeout: 5.0)
    // folder cell is harder to find in SwiftUI version
  }
  
  func reset(modeButton: XCUIElement) throws
  {
    try XCTContext.runActivity(named: "Resetting") { _ in
      env.write("some stuff", to: "README1.txt")
      env.write("other stuff", to: "REAME_")
      try env.git.run(args: ["add", "REAME_"])

      HistoryList.row(2).rightClick()
      HistoryList.ContextMenu.resetItem.click()
      XCTAssertTrue(ResetSheet.window.waitForExistence(timeout: 0.5))
      modeButton.click()
      ResetSheet.resetButton.click()
    }
  }
  
  func testResetSoft() throws
  {
    env.open()
    
    try reset(modeButton: ResetSheet.softButton)
    BranchList.stagingCell.click()

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
  
  func testResetMixed() throws
  {
    env.open()
    
    try reset(modeButton: ResetSheet.mixedButton)
    BranchList.stagingCell.click()

    // Temporary workaround
    StagedFileList.refreshButton.click()

    StagedFileList.assertFiles([])
    WorkspaceFileList.assertFiles(["README.md", "README1.txt", "REAME_",
                                   "UntrackedImage.png", "hero_slide1.png",
                                   "jquery-1.8.1.min.js"])
  }
  
  func testResetHard() throws
  {
    env.open()
    
    try reset(modeButton: ResetSheet.hardButton)
    BranchList.stagingCell.click()
    
    // Temporary workaround
    StagedFileList.refreshButton.click()

    StagedFileList.assertFiles([])
    // Untracked files survive a hard reset
    WorkspaceFileList.assertFiles(["UntrackedImage.png"])
  }
  
  func modifyAndStage(file: String, text: String) throws
  {
    env.write(text, to: file)
    try env.git.run(args: ["add", file])
  }
  
  func testFilterComments() throws
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
    
    try modifyAndStage(file: "README1.txt", text: "some stuff")

    env.open()
    
    BranchList.stagingCell.click()
    if (CommitEntry.stripCheck.value as? Int) == 0 {
      CommitEntry.stripCheck.click()
    }
    CommitEntry.messageField.click()
    CommitEntry.messageField.typeText(enteredText)
    CommitEntry.commitButton.click()
    HistoryList.row("First line ⋯").click()
    XCTAssertEqual(CommitHeader.messageField.stringValue, expectedText)
  }
  
  func testDontFilterComments() throws
  {
    let enteredText = """
          First line
          # comment line
          Second line
          """

    try modifyAndStage(file: "README1.txt", text: "some stuff")

    env.open()
    
    Sidebar.Branches.stagingCell.click()
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

      Sidebar.Branches.stagingCell.click()
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
