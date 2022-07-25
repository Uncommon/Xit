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
    XCTAssert(PasswordPanel.sheet.waitForExistence(timeout: 5))
    
    PasswordPanel.cancel.click()
    wait(for: [absence(of: PasswordPanel.sheet)], timeout: 2)
    // Just to check that the app isn't frozen
    XCTAssert(XitApp.menuBars.menuBarItems["File"].exists)
//    expectation(for: .init(format: "enabled == true"),
//                evaluatedWith: Clone.cloneButton, handler: nil)
//    waitForExpectations(timeout: 5)
  }
}
