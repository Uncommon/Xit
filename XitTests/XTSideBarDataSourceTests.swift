import Foundation
@testable import Xit

class XTSidebarDataSourceTest: XTTest
{
  var outline = MockSidebarOutline()
  var sbds = XTSideBarDataSource()

  func groupItem(_ row: XTGroupIndex) -> XTSideBarGroupItem
  {
    return sbds.outlineView(outline, child: row.rawValue, ofItem: nil)
           as! XTSideBarGroupItem
  }
  
  override func setUp()
  {
    super.setUp()
    sbds.outline = outline
    outline.dataSource = sbds
    sbds.repo = repository
  }

  func testTags()
  {
    XCTAssertTrue(repository.createTag("t1", targetSHA: repository.headSHA!,
                                       message: "msg"))
    sbds.reload()
    waitForRepoQueue()
    
    let rowCount = sbds.outlineView(outline, numberOfChildrenOfItem: nil)
    
    XCTAssertEqual(rowCount, 6)
    
    let tagsGroup = groupItem(.tags)
    let tagCount = sbds.outlineView(outline, numberOfChildrenOfItem: tagsGroup)
    
    XCTAssertEqual(tagCount, 1)
    
    let tag = sbds.outlineView(outline, child: 0, ofItem: tagsGroup)
              as! XTSideBarItem
    let expandable = sbds.outlineView(outline, isItemExpandable: tag)
    
    XCTAssertNotNil(tag.model)
    XCTAssertNotNil(tag.model?.shaToSelect)
    XCTAssertFalse(expandable)
    
    let view = sbds.outlineView(outline, viewFor: nil, item: tag)
               as! NSTableCellView
    
    XCTAssertEqual(view.textField?.stringValue, "t1")
  }
  
  func testBranches()
  {
    XCTAssertTrue(repository.createBranch("b1"))
    sbds.reload()
    waitForRepoQueue()
    
    let branches = groupItem(.branches)
    let branchCount = sbds.outlineView(outline,
                                       numberOfChildrenOfItem: branches)
    let branchNames = ["b1", "master"]
  
    XCTAssertEqual(branchCount, 2)
    for b in 0...1 {
      let branch = sbds.outlineView(outline, child: b, ofItem: branches)
                   as! XTSideBarItem
      let expandable = sbds.outlineView(outline, isItemExpandable: branch)
      
      XCTAssertNotNil(branch.model)
      XCTAssertNotNil(branch.model?.shaToSelect)
      XCTAssertFalse(expandable)
      
      let view = sbds.outlineView(outline, viewFor: nil, item: branch)
                 as! NSTableCellView
    
      XCTAssertEqual(view.textField?.stringValue, branchNames[b])
    }
  }
}

class MockSidebarOutline: NSOutlineView
{
  override func make(withIdentifier identifier: String,
                     owner: Any?) -> NSView?
  {
    let result = XTSidebarTableCellView(frame: NSRect(x: 0, y: 0,
                                                      width: 185, height: 20))
    let textField = NSTextField(frame: NSRect(x: 26, y: 3,
                                              width: 163, height: 17))
    let imageView = NSImageView(frame: NSRect(x: 5, y: 2,
                                              width: 16, height: 16))
    let statusImage = NSImageView(frame: NSRect(x: 171, y: 2,
                                                width: 16, height: 16))
    let statusButton = NSButton(frame: NSRect(x: 171, y: 2,
                                              width: 16, height: 16))
    let statusText = NSButton(title: "10", target: nil, action: nil)
    
    for view in [textField, imageView, statusImage, statusButton, statusText] {
      result.addSubview(view)
    }
    result.textField = textField
    result.imageView = imageView
    result.statusImage = statusImage
    result.statusButton = statusButton
    result.statusText = statusText
    
    return result
  }
}
