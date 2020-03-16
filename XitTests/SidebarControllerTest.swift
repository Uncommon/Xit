import XCTest
@testable import Xit


class TestingSidebarHandler : SidebarHandler
{
  var repoUIController: RepositoryUIController?

  var repo: XTRepository!
  {
    didSet
    {
      repoUIController = FakeRepoUIController(repository: repo)
    }
  }
  var window: NSWindow? { return nil }
  var selectedItem: SidebarItem? = nil
  var selectedStash: UInt? = nil
  
  func targetItem() -> SidebarItem?
  {
    return selectedItem
  }
  
  func stashIndex(for item: SidebarItem) -> UInt?
  {
    return selectedStash
  }
}

class SidebarHandlerTest: XTTest
{
  let handler = TestingSidebarHandler()
  
  override func setUp()
  {
    super.setUp()
    handler.repo = repository
  }
  
  func item(forBranch branch: String) -> SidebarItem?
  {
    guard let commit = GitCommit(ref: "refs/heads/\(branch)",
                                     repository: repository.gitRepo)
    else {
      XCTFail("can't get commit for branch \(branch)")
      return nil
    }
    let selection = CommitSelection(repository: repository,
                                    commit: commit)
    
    return LocalBranchSidebarItem(title: branch, selection: selection)
  }
  
  func checkDeleteBranch(named branch: String) -> Bool
  {
    let menuItem = NSMenuItem(
      title: "Delete",
      action: #selector(SidebarController.deleteBranch(_:)),
      keyEquivalent: "")
    
    handler.selectedItem = item(forBranch: branch)
    return handler.validate(sidebarCommand: menuItem)
  }
  
  func testDeleteCurrentBranch()
  {
    XCTAssertFalse(checkDeleteBranch(named: "master"))
  }
  
  func testDeleteOtherBranch()
  {
    XCTAssertNoThrow(_ = try repository.createBranch(named: "other",
                                                     target: "refs/heads/master"))
    XCTAssertTrue(checkDeleteBranch(named: "other"))
  }

  func makeTwoStashes()
  {
    XCTAssertTrue(writeTextToFile1("second text"))
    try! repository.saveStash(name: "s1",
                              keepIndex: false,
                              includeUntracked: false,
                              includeIgnored: true)
    XCTAssertTrue(writeTextToFile1("third text"))
    try! repository.saveStash(name: "s2",
                              keepIndex: false,
                              includeUntracked: false,
                              includeIgnored: true)
  }
  
  /// Checks that the remaining stashes have the expected names
  func currentStashes() -> [String]
  {
    return repository.stashes.map { $0.message ?? "" }
  }
  
  func composeStashes(_ expectedStashes: [String]) -> [String]
  {
    return expectedStashes.map { "On master: \($0)" }
  }
  
  func doStashAction(index: UInt, expectedRemains: [String],
                     expectedText: String, action: () -> Void)
  {
    var expected = composeStashes([ "s2", "s1" ])
  
    makeTwoStashes()
    XCTAssertEqual(currentStashes(), expected)
    
    handler.selectedItem = StashSidebarItem(title: expected[Int(index)])
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
        action: #selector(SidebarController.mergeBranch(_:)),
        keyEquivalent: "")
    
    XCTAssertTrue(repository.createBranch("branch"))
    handler.selectedItem = item(forBranch: "branch")
    XCTAssertNotNil(try? repository.checkOut(branch: "master"))
    XCTAssertTrue(handler.validate(sidebarCommand: menuItem))
    XCTAssertEqual(menuItem.title, "Merge \"branch\" into \"master\"")
  }
  
  func testMergeDisabled()
  {
    let menuItem = NSMenuItem(
      title: "Merge",
      action: #selector(SidebarController.mergeBranch(_:)),
      keyEquivalent: "")
    
    handler.selectedItem = item(forBranch: "master")
    XCTAssertFalse(handler.validate(sidebarCommand: menuItem))
  }
}
