import XCTest
@testable import Xit
@testable import XitGit
import XitGitTestSupport


class TestingSidebarHandler : SidebarCommandHandler
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
  var handler: TestingSidebarHandler!

  @MainActor
  override func setUp()
  {
    super.setUp()
    
    let controller = FakeRepoUIController(repository: repository)
    
    handler = .init()
    handler.repo = repository
    handler.repoUIController = controller
    controller.repoController = GitRepositoryController(repository: repository)
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
  
  @MainActor
  func checkDeleteBranch(named branch: String) -> Bool
  {
    let menuItem = NSMenuItem(
      title: "Delete",
      action: #selector(SidebarController.deleteBranch(_:)),
      keyEquivalent: "")
    
    handler.selectedItem = item(forBranch: branch)
    return handler.validate(sidebarCommand: menuItem)
  }
  
  @MainActor
  func testDeleteCurrentBranch()
  {
    XCTAssertFalse(checkDeleteBranch(named: "main"))
  }
  
  @MainActor
  func testDeleteOtherBranch() throws
  {
    _ = try repository.createBranch(named: "other",
                                    target: "refs/heads/main")
    XCTAssertTrue(checkDeleteBranch(named: "other"))
  }

  func makeTwoStashes() throws
  {
    try execute(in: repository) {
      Write("second text", to: .file1)
      SaveStash("s1")
      Write("third text", to: .file1)
      SaveStash("s2")
    }
  }
  
  /// Checks that the remaining stashes have the expected names
  func currentStashes() -> [String]
  {
    return repository.stashes.map { $0.message ?? "" }
  }
  
  func composeStashes(_ expectedStashes: [String]) -> [String]
  {
    return expectedStashes.map { "On main: \($0)" }
  }
  
  @MainActor
  func doStashAction(index: UInt, expectedRemains: [String],
                     expectedText: String, action: () -> Void) throws
  {
    var expected = composeStashes([ "s2", "s1" ])
  
    try makeTwoStashes()
    XCTAssertEqual(currentStashes(), expected)
    
    handler.selectedItem = StashSidebarItem(title: expected[Int(index)])
    handler.selectedStash = index
    
    action()
    waitForRepoQueue()
    expected = composeStashes(expectedRemains)
    XCTAssertEqual(currentStashes(), expected)
    
    let text = try String(contentsOfFile: file1Path, encoding: .ascii)
    
    XCTAssertEqual(text, expectedText)
  }
  
  @MainActor
  func testPopStash1() throws
  {
    try doStashAction(index: 1,
                      expectedRemains: [ "s2" ],
                      expectedText: "second text",
                      action: { handler.popStash() })
  }
  
  @MainActor
  func testPopStash2() throws
  {
    try doStashAction(index: 0,
                      expectedRemains: [ "s1" ],
                      expectedText: "third text",
                      action: { handler.popStash() })
  }
  
  @MainActor
  func testApplyStash1() throws
  {
    try doStashAction(index: 1,
                      expectedRemains: [ "s2", "s1" ],
                      expectedText: "second text",
                      action: { handler.applyStash() })
  }
  
  @MainActor
  func testApplyStash2() throws
  {
    try doStashAction(index: 0,
                      expectedRemains: [ "s2", "s1" ],
                      expectedText: "third text",
                      action: { handler.applyStash() })
  }
  
  @MainActor
  func testDropStash1() throws
  {
    try doStashAction(index: 1,
                      expectedRemains: [ "s2" ],
                      expectedText: "some text",
                      action: { handler.dropStash() })
  }
  
  @MainActor
  func testDropStash2() throws
  {
    try doStashAction(index: 0,
                      expectedRemains: [ "s1" ],
                      expectedText: "some text",
                      action: { handler.dropStash() })
  }
  
  @MainActor
  func testMergeText() throws
  {
    let menuItem = NSMenuItem(
        title: "Merge",
        action: #selector(SidebarController.mergeBranch(_:)),
        keyEquivalent: "")

    try execute(in: repository) {
      CreateBranch("branch")
    }
    handler.selectedItem = item(forBranch: "branch")
    XCTAssertNotNil(try? repository.checkOut(branch: "main"))
    XCTAssertTrue(handler.validate(sidebarCommand: menuItem))
    XCTAssertEqual(menuItem.title, "Merge \"branch\" into \"main\"")
  }
  
  @MainActor
  func testMergeDisabled()
  {
    let menuItem = NSMenuItem(
      title: "Merge",
      action: #selector(SidebarController.mergeBranch(_:)),
      keyEquivalent: "")
    
    handler.selectedItem = item(forBranch: "main")
    XCTAssertFalse(handler.validate(sidebarCommand: menuItem))
  }
}
