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
    
    let statusIndicator = Sidebar.workspaceStatusIndicator(branch: "master")
    
    // The remote hasn't been fetched since the above commit, so this repo
    // doesn't know yet that it's behind.
    XCTAssertFalse(statusIndicator.exists)
    
    Window.fetchButton.press(forDuration: 0.25)
    Window.fetchMenu.menuItems["Fetch Remote \"\(remoteName)\""].click()
    wait(for: [hiding(of: Window.progressSpinner)], timeout: 3.0)
    
    XCTAssertTrue(statusIndicator.exists)
    XCTAssertEqual(statusIndicator.title, "↓1")
  }
}

class PushTests: UnicodeRepoUITests
{
  let newFileName = "newfile.txt"

  var statusIndicator: XCUIElement
  { Sidebar.workspaceStatusIndicator(branch: "master") }
  
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
    
    XCTAssertTrue(statusIndicator.exists && statusIndicator.title == "↑1")
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

    // check in git whether the tracking branch is set
    let result = env.git.run(args: ["branch", "-lvv", branchName])
    let trackingFound = result.contains("[\(remoteName)/\(branchName)]")
    
    XCTAssertEqual(tracking, trackingFound, "tracking branch not set correctly")
    
    if tracking {
      // Cloud icon should appear in the sidebar
      wait(for: [presence(of: indicator)], timeout: 2.0)
    }
    else {
      XCTAssertFalse(indicator.exists)
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
      Sidebar.Branches.cell(named: newBranchName).rightClick()
      Sidebar.remoteBranchPopup
             .menuItems[.RemoteBranchPopup.createTracking].tap()
    }
  }
  
  func testCreateTrackingBranch()
  {
    env.open()
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
      XCTAssert(!CreateTrackingSheet.window.exists, "sheet did not open")
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
      
      XCTAssertEqual(currentBranch, newBranchName)
      Sidebar.assertCurrentBranch(newBranchName)
    }
  }
}
