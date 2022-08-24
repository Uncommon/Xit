import XCTest

/// Tests that use actual network operations
class NetworkTests: XCTestCase
{
  let env = TestXitEnvironment()

  let testRepoURL = "https://github.com/Uncommon/Testing.git"

  override func setUpWithError() throws
  {
    continueAfterFailure = false
    env.open()
  }

  func testPrivateRepository() throws
  {
    XCTContext.runActivity(named: "Open clone panel") { _ in
      XitApp.menuBars.menuBarItems["File"].click()
      XitApp.menuItems["Clone..."].click()
    }

    Clone.urlField.click()
    Clone.urlField.typeText(testRepoURL)
    XCTAssert(Clone.signInButton.waitForExistence(timeout: 5))

    Clone.signInButton.click()
    PasswordPanel.cancel.click()
    wait(for: [absence(of: PasswordPanel.sheet)], timeout: 2)
    XCTAssertFalse(Clone.cloneButton.isEnabled)
  }

  func testTokenSignIn() throws
  {
    guard let token = externalFileContent("github_token.txt")
    else {
      throw XCTSkip("token not available")
    }
    XCTContext.runActivity(named: "Open clone panel") { _ in
      XitApp.menuBars.menuBarItems["File"].click()
      XitApp.menuItems["Clone..."].click()
    }

    Clone.urlField.click()
    Clone.urlField.typeText(testRepoURL)
    XCTAssert(Clone.signInButton.waitForExistence(timeout: 5))

    Clone.signInButton.click()
    PasswordPanel.passwordField.click()
    PasswordPanel.passwordField.typeText(token)
    PasswordPanel.ok.click()
    wait(for: [absence(of: Clone.signInButton)], timeout: 2)
    XCTAssertTrue(Clone.cloneButton.isEnabled)
  }
}
