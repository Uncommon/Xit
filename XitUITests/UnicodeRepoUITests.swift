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
    throw XCTSkip("pop-up menu tests aren't working")
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
    
    Window.fetchButton.press(forDuration: 0.5)
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
    throw XCTSkip("pop-up menu tests aren't working")
    Window.pushButton.press(forDuration: 0.5)
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
    throw XCTSkip("pop-up menu tests aren't working")
    env.open()
    
    let indicator = Sidebar.trackingStatusIndicator(branch: branchName)

    XCTAssertFalse(indicator.exists)
    
    Window.pushButton.press(forDuration: 0.5)
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
