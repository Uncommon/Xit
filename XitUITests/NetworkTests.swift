import XCTest

/// Tests that use actual network operations
class NetworkTests: XCTestCase
{
  let env = TestXitEnvironment()

  override func setUpWithError() throws
  {
    continueAfterFailure = false
    env.open()
  }

  func testExample() throws
  {
    XCTContext.runActivity(named: "Open clone panel") { _ in
      XitApp.menuBars.menuBarItems["File"].click()
      XitApp.menuItems["Clone..."].click()
    }

    Clone.urlField.click()
    Clone.urlField.typeText("https://github.com/Uncommon/Testing.git")
    XCTAssert(Clone.signInButton.waitForExistence(timeout: 5))

    Clone.signInButton.click()
    PasswordPanel.cancel.click()
    wait(for: [absence(of: PasswordPanel.sheet)], timeout: 2)
    // Just to check that the app isn't frozen
    XCTAssert(XitApp.menuBars.menuBarItems["File"].exists)
  }
}
