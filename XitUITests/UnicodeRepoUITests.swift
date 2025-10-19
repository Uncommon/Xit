import XCTest

/// Tests using the "unicode" repository
class UnicodeRepoUITests: XCTestCase
{
  var env: TestRepoEnvironment!

  let remoteName = "twin"

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
}

class FetchTests: UnicodeRepoUITests
{
  func testFetchRemote() throws
  {
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
    
    let statusIndicator = Sidebar.trackingStatusIndicator(branch: "master")
    
    // The remote hasn't been fetched since the above commit, so this repo
    // doesn't know yet that it's behind.
    XCTAssertFalse(statusIndicator.exists)
    
    Window.fetchButton.press(forDuration: 0.25)
    Window.fetchMenu.menuItems["Fetch Remote \"\(remoteName)\""].click()
    wait(for: [hiding(of: Window.progressSpinner)], timeout: 3.0)
    
    XCTAssertTrue(statusIndicator.exists)
    XCTAssertEqual(statusIndicator.value as? String, "↓1")
  }
}

class PushTests: UnicodeRepoUITests
{
  let newFileName = "newfile.txt"

  var statusIndicator: XCUIElement
  { Sidebar.trackingStatusIndicator(branch: "master") }
  
  override func setUp()
  {
    super.setUp()
    
    continueAfterFailure = false
    XCTAssert(env.makeBareRemote(named: remoteName))
    // Track the remote branch
    env.git.run(args: ["branch", "-u", "\(remoteName)/master"])
    
    // Add a commit so the local branch is ahead
    env.write("some content", to: newFileName)
    env.git.run(args: ["add", newFileName])
    // Use -c because for some reason it doesn't pick up the global config
    env.git.run(args: ["-c", "user.name=Me",
                       "-c", "user.email=me@example.com",
                       "commit", "-m", "message",
    ])
    
    env.open()
    
    let cell = Sidebar.Branches.branchCell("master")
    
    XCTAssertTrue(cell.exists)
    XCTAssertTrue(statusIndicator.exists, "status indicator not found")
    XCTAssertEqual(statusIndicator.value as? String, "↑1", "unexpected status")
  }
  
  func testPushDefault()
  {
    Window.pushButton.click()
    
    Window.window.sheets.buttons["Push"].click()
    wait(for: [hiding(of: Window.progressSpinner)], timeout: 2.0)

    XCTWaiter(delegate: self).wait(for: [hiding(of: statusIndicator)],
                                   timeout: 2.0)
  }
  
  func testPushAnyTracking() throws
  {
    Window.pushButton.press(forDuration: 0.25)
    Window.pushMenu.menuItems["Push to Any Tracking Branches on \"\(remoteName)\""].click()
    
    Window.window.sheets.buttons["Push"].click()
    wait(for: [hiding(of: Window.progressSpinner)], timeout: 3.0)

    XCTWaiter(delegate: self).wait(for: [absence(of: statusIndicator)],
                                   timeout: 2.0)
  }
}

class PushNewTests: UnicodeRepoUITests
{
  let branchName = "newBranch"
  
  override func setUp()
  {
    super.setUp()
    
    XCTAssert(env.makeBareRemote(named: remoteName))
    
    env.git.checkOut(newBranch: branchName)
  }
  
  func pushNewBranch(tracking: Bool) throws
  {
    env.open()
    
    let indicator = Sidebar.trackingStatusIndicator(branch: branchName)

    XCTAssertFalse(indicator.exists)
    
    try XCTContext.runActivity(named: "Push branch") { _ in
      Window.pushButton.press(forDuration: 0.25)
      Window.pushMenu.menuItems["Push to New Remote Branch..."].click()
      
      let trackingButton = PushNewSheet.setTrackingCheck
      
      wait(for: [presence(of: trackingButton)], timeout: 2.0)
      
      let buttonValue: Int = try testConvert(trackingButton.value)
      
      // Should be checked by default
      XCTAssertTrue(buttonValue != 0)
      if !tracking {
        trackingButton.click()
      }
      
      PushNewSheet.pushButton.click()
      wait(for: [hiding(of: Window.progressSpinner)], timeout: 2.0)
    }

    XCTContext.runActivity(named: "Check repo for tracking branch") { _ in
      let result = env.git.run(args: ["branch", "-lvv", branchName])
      let trackingFound = result.contains("[\(remoteName)/\(branchName)]")
      
      XCTAssertEqual(tracking, trackingFound, "tracking branch not set correctly")
    }
    
    XCTContext.runActivity(named: "Check for indicator") { _ in
      if tracking {
        XCTAssert(indicator.waitForExistence(timeout: 2.0),
                  "tracking icon did not appear")
      }
      else {
        XCTAssertFalse(indicator.exists)
      }
    }
  }
  
  func testNewBranchTracking() throws
  {
    try pushNewBranch(tracking: true)
  }
  
  func testNewBranchNoTracking() throws
  {
    try pushNewBranch(tracking: false)
  }
}

class RemoteBranchTests: UnicodeRepoUITests
{
  let newBranchName = "newBranch"
  
  override func setUp()
  {
    super.setUp()
    
    XCTAssert(env.makeRemoteCopy(named: remoteName))
    env.remoteGit.checkOut(newBranch: newBranchName)
    env.git.run(args: ["fetch", remoteName])
  }
  
  func openCreateTrackingSheet()
  {
    XCTContext.runActivity(named: "open Create Tracking Branch sheet") {
      _ in
      Sidebar.Remotes.cell(named: newBranchName)
        .staticTexts.firstMatch // Right click on the cell itself seems to miss
        .rightClick()
      XitApp.windows.menuItems[UIString.createTrackingBranch.rawValue].tap()
    }
  }
  
  func testCreateTrackingBranch()
  {
    env.open()
    Sidebar.Tab.remotes.click()
    openCreateTrackingSheet()

    XCTContext.runActivity(named: "check initial setup") { _ in
      XCTAssert(CreateTrackingSheet.window.exists, "sheet did not open")
      XCTAssertEqual(CreateTrackingSheet.prompt.stringValue,
                     "Create a local branch tracking \"\(remoteName)/\(newBranchName)\"")
      XCTAssertEqual(CreateTrackingSheet.branchName.stringValue, newBranchName)
      XCTAssert(CreateTrackingSheet.cancelButton.isEnabled)
      XCTAssert(CreateTrackingSheet.createButton.isEnabled)
    }

    XCTContext.runActivity(named: "test cancel") { _ in
      CreateTrackingSheet.cancelButton.tap()
      XCTAssert(!CreateTrackingSheet.window.exists, "sheet did not close")
    }

    openCreateTrackingSheet()
    
    XCTContext.runActivity(named: "check empty name") { _ in
      CreateTrackingSheet.branchName.typeKey(.delete, modifierFlags: [])
      XCTAssertFalse(CreateTrackingSheet.createButton.isEnabled,
                     "create button should be disabled with empty name")
    }
    XCTContext.runActivity(named: "check invalid name") { _ in
      CreateTrackingSheet.branchName.typeText("/")
      XCTAssertFalse(CreateTrackingSheet.createButton.isEnabled,
                     "create button should be disabled with invalid name")
      XCTAssertEqual(CreateTrackingSheet.errorMessage.stringValue,
                     "Not a valid name")
    }
    XCTContext.runActivity(named: "check conflicting name") { _ in
      CreateTrackingSheet.branchName.typeKey("a", modifierFlags: .command)
      CreateTrackingSheet.branchName.typeText("master")
      XCTAssertFalse(CreateTrackingSheet.createButton.isEnabled,
                     "create button should be disabled with conflicting name")
    }
    
    XCTContext.runActivity(named: "create with same name") { _ in
      CreateTrackingSheet.branchName.typeKey("a", modifierFlags: .command)
      CreateTrackingSheet.branchName.typeText(newBranchName)
      CreateTrackingSheet.createButton.tap()
      XCTAssertFalse(CreateTrackingSheet.window.exists,
                     "sheet stayed open")
    }
    
    XCTContext.runActivity(named: "verify branch is checked out") { _ in
      let currentBranch = env.git.currentBranch()
      
      XCTAssertEqual(currentBranch, newBranchName,
                     "new tracking branch doesn't match")
      Sidebar.Tab.local.tap()
      Sidebar.assertCurrentBranch(newBranchName)
    }
  }
}
