import XCTest

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
}

class FetchTests: UnicodeRepoUITests
{
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
    
    let statusIndicator = Sidebar.statusIndicator(branch: "master")
    
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
}

class PushTests: UnicodeRepoUITests
{
  let remoteName = "twin"
  let newFileName = "newfile.txt"

  var statusIndicator: XCUIElement { Sidebar.statusIndicator(branch: "master") }
  
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
    // Wait for the progress spinner to go away
    XCTAssertTrue(Window.proxyIcon.waitForExistence(timeout: 1.0))
    
    XCTWaiter(delegate: self).wait(for: [absence(of: statusIndicator)],
                                   timeout: 1.0)
  }
  
  func testPushAnyTracking()
  {
    Window.pushButton.press(forDuration: 0.5)
    Window.pushMenu.menuItems["Push to any tracking branches on \"\(remoteName)\""].click()
    
    Window.window.sheets.buttons["Push"].click()
    // Wait for the progress spinner to go away
    XCTAssertTrue(Window.proxyIcon.waitForExistence(timeout: 1.0))
    
    XCTWaiter(delegate: self).wait(for: [absence(of: statusIndicator)],
                                   timeout: 1.0)
  }
}
