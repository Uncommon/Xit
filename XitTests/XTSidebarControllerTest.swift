import XCTest
@testable import Xit

class XTTestingSidebarHandler : XTSidebarHandler
{
  var repo: XTRepository!
  var selectedItem: XTSideBarItem? = nil
  
  func targetItem() -> XTSideBarItem?
  {
    return self.selectedItem
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
}
