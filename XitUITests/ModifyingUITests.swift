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
  
  func testRenameBranch()
  {
    env.open()
    
    let oldBranchName = "and-how"
    let newBranchName = "and-then"

    Sidebar.list.staticTexts[oldBranchName].rightClick()
    XitApp.menuItems["Rename"].click()
    XitApp.typeText("\(newBranchName)\r")
    XCTAssertTrue(Sidebar.list.staticTexts[newBranchName].exists)

    let branches = env.git.branches()
    
    XCTAssertFalse(branches.contains(oldBranchName))
    XCTAssertTrue(branches.contains(newBranchName))
  }
  
  func testTitleBarBranchSwitch()
  {
    env.open()
    
    let otherBranch = "feature"
    
    Window.branchPopup.click()
    XitApp.menuItems[otherBranch].click()
    XCTAssertEqual(Window.branchPopup.value as? String, otherBranch)
    
    let currentBranch = env.git.currentBranch()
    
    XCTAssertEqual(currentBranch, otherBranch)
  }
  
  func testFilterBranchFolder()
  {
    let folderName = "folder"
    let subBranchName = "and-why"
    
    _ = env.git.run(args: ["branch", "\(folderName)/\(subBranchName)"])
    env.open()
    
    let newBranchCell = Sidebar.cell(named: "new")

    XCTAssertTrue(newBranchCell.exists)
    
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
    env.write("some stuff", to: "README1.txt")
    env.write("other stuff", to: "REAME_")
    env.git.run(args: ["add", "REAME_"])
    HistoryList.row(1).rightClick()
    HistoryList.ContextMenu.resetItem.click()
    XCTAssertTrue(ResetSheet.window.waitForExistence(timeout: 0.5))
    modeButton.click()
    ResetSheet.resetButton.click()
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
}

/// Tests using the "unicode" repository
class UnicodeRepoUITests: XCTestCase
{
  var env: TestRepoEnvironment!

  override func setUp()
  {
    guard let env = TestRepoEnvironment(.unicode, testName: name)
    else {
      XCTFail("Environment setup failed")
      continueAfterFailure = false
      return
    }
    
    self.env = env
  }
  
  func testFetchRemote()
  {
    let remoteName = "twin"
    let newFileName = "newfile.txt"
    
    XCTAssert(env.makeRemoteCopy(named: remoteName))
    // Track the remote branch
    env.git.run(args: ["branch", "-u", "\(remoteName)/master"])
    
    // Add a commit so the remote is ahead
    env.writeRemote("some content", to: newFileName)
    env.remoteGit.run(args: ["add", newFileName])
    // Use -c because for some reason it doesn't pick up the global config
    env.remoteGit.run(args: ["-c", "user.name=Me",
                             "-c", "user.email=me@example.com",
                             "commit", "-m", "message",
    ])
    
    env.open()
    
    let masterCell = Sidebar.list.cells
                            .containing(.staticText, identifier: "master")
    let statusIndicator = masterCell.buttons["workspaceStatus"]
    
    // The remote hasn't been fetched since the above commit, so this repo
    // doesn't know yet that it's behind.
    XCTAssertFalse(statusIndicator.exists)
    
    Window.fetchButton.press(forDuration: 0.5)
    Window.fetchMenu.menuItems["Fetch remote \"\(remoteName)\""].click()
    // Wait for the progress spinner to go away
    XCTAssertTrue(Window.proxyIcon.waitForExistence(timeout: 1.0))
    
    XCTAssertTrue(statusIndicator.exists)
    XCTAssertEqual(statusIndicator.title, "↓1")
  }
  
  func testPushRemote()
  {
    let remoteName = "twin"
    let newFileName = "newfile.txt"
    
    XCTAssert(env.makeBareRemote(named: remoteName))
    // Track the remote branch
    env.git.run(args: ["branch", "-u", "\(remoteName)/master"])
    
    // Add a commit so the remote is ahead
    env.write("some content", to: newFileName)
    env.git.run(args: ["add", newFileName])
    // Use -c because for some reason it doesn't pick up the global config
    env.git.run(args: ["-c", "user.name=Me",
                       "-c", "user.email=me@example.com",
                       "commit", "-m", "message",
    ])
    
    env.open()
    
    let masterCell = Sidebar.list.cells
                            .containing(.staticText, identifier: "master")
    let statusIndicator = masterCell.buttons["workspaceStatus"]
    
    // Local branch is ahead
    XCTAssertTrue(statusIndicator.exists)
    XCTAssertEqual(statusIndicator.title, "↑1")

    Window.pushButton.press(forDuration: 0.5)
    Window.pushMenu.menuItems["Push to any tracking branches on \"\(remoteName)\""].click()
    Window.window.sheets.buttons["Push"].click()
    // Wait for the progress spinner to go away
    XCTAssertTrue(Window.proxyIcon.waitForExistence(timeout: 1.0))
    
    XCTWaiter(delegate: self).wait(for: [absence(of: statusIndicator)], timeout: 1.0)
  }
}
