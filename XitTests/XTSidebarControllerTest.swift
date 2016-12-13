import XCTest
@testable import Xit


class XTTestingSidebarHandler : SidebarHandler
{
  var repo: XTRepository!
  var window: NSWindow? { return nil }
  var selectedItem: XTSideBarItem? = nil
  var selectedStash: UInt? = nil
  
  func targetItem() -> XTSideBarItem?
  {
    return selectedItem
  }
  
  func stashIndex(for item: XTSideBarItem) -> UInt?
  {
    return selectedStash
  }
}

class XTSidebarHandlerTest: XTTest
{
  let handler = XTTestingSidebarHandler()
  
  override func setUp()
  {
    super.setUp()
    handler.repo = repository
  }
  
  func checkDeleteBranch(named branch: String) -> Bool
  {
    let menuItem = NSMenuItem(
      title: "Delete",
      action: #selector(XTSidebarController.deleteBranch(_:)),
      keyEquivalent: "")
    
    handler.selectedItem = XTLocalBranchItem(title: branch)
    return handler.validate(sidebarCommand: menuItem)
  }
  
  func testDeleteCurrentBranch()
  {
    XCTAssertFalse(checkDeleteBranch(named: "master"))
  }
  
  func testDeleteOtherBranch()
  {
    XCTAssertTrue(checkDeleteBranch(named: "other"))
  }

  func makeTwoStashes()
  {
    XCTAssertTrue(writeText(toFile1: "second text"))
    XCTAssertTrue(repository.saveStash("s1", includeUntracked: false))
    XCTAssertTrue(writeText(toFile1: "third text"))
    XCTAssertTrue(repository.saveStash("s2", includeUntracked: false))
  }
  
  /// Checks that the remaining stashes have the expected names
  func currentStashes() -> [String]
  {
    var stashes = [String]()
    
    repository.readStashes { (commit, index, name) in
      stashes.append(name)
    }
    return stashes
  }
  
  func composeStashes(_ expectedStashes: [String]) -> [String]
  {
    return expectedStashes.enumerated().map {
        "stash@{\($0.offset)} On master: \($0.element)" }
  }
  
  func doStashAction(index: UInt, expectedRemains: [String],
                     expectedText: String, action: () -> Void)
  {
    var expected = composeStashes([ "s2", "s1" ])
  
    makeTwoStashes()
    XCTAssertEqual(currentStashes(), expected)
    
    handler.selectedItem = XTStashItem(title: expected[Int(index)])
    handler.selectedStash = index
    
    action()
    waitForRepoQueue()
    expected = composeStashes(expectedRemains)
    XCTAssertEqual(currentStashes(), expected)
    
    guard let text = try? String(contentsOfFile: file1Path, encoding: .ascii)
    else {
      XCTFail()
      return
    }
    
    XCTAssertEqual(text, expectedText)
  }
  
  func testPopStash1()
  {
    doStashAction(index: 1,
                  expectedRemains: [ "s2" ],
                  expectedText: "second text",
                  action: { handler.popStash() })
  }
  
  func testPopStash2()
  {
    doStashAction(index: 0,
                  expectedRemains: [ "s1" ],
                  expectedText: "third text",
                  action: { handler.popStash() })
  }
  
  func testApplyStash1()
  {
    doStashAction(index: 1,
                  expectedRemains: [ "s2", "s1" ],
                  expectedText: "second text",
                  action: { handler.applyStash() })
  }
  
  func testApplyStash2()
  {
    doStashAction(index: 0,
                  expectedRemains: [ "s2", "s1" ],
                  expectedText: "third text",
                  action: { handler.applyStash() })
  }
  
  func testDropStash1()
  {
    doStashAction(index: 1,
                  expectedRemains: [ "s2" ],
                  expectedText: "some text",
                  action: { handler.dropStash() })
  }
  
  func testDropStash2()
  {
    doStashAction(index: 0,
                  expectedRemains: [ "s1" ],
                  expectedText: "some text",
                  action: { handler.dropStash() })
  }
  
  func testMergeText()
  {
    let menuItem = NSMenuItem(
        title: "Merge",
        action: #selector(XTSidebarController.mergeBranch(_:)),
        keyEquivalent: "")
    
    handler.selectedItem = XTLocalBranchItem(title: "branch")
    XCTAssertTrue(repository.createBranch("branch"))
    XCTAssertNotNil(try? repository.checkout("master"))
    XCTAssertTrue(handler.validate(sidebarCommand: menuItem))
    XCTAssertEqual(menuItem.title, "Merge branch into master")
  }
  
  func testMergeDisabled()
  {
    let menuItem = NSMenuItem(
      title: "Merge",
      action: #selector(XTSidebarController.mergeBranch(_:)),
      keyEquivalent: "")
    
    handler.selectedItem = XTLocalBranchItem(title: "master")
    XCTAssertFalse(handler.validate(sidebarCommand: menuItem))
  }
}
