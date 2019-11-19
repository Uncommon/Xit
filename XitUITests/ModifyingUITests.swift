import XCTest

/// Tests that change the repository, and must therefore get a fresh copy of
/// the test repo for each run.
class ModifyingUITests: XCTestCase
{
  var env: TestRepoEnvironment!

  override func setUp()
  {
    env = TestRepoEnvironment(.testApp)!
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
}
