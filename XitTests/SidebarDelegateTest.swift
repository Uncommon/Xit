import Foundation
import XCTest
@testable import Xit

class SidebarDelegateTest: XTTest
{
  var outline = MockSidebarOutline()
  let sbDelegate = SidebarDelegate()
  var model: SidebarDataModel!
  
  override func setUp()
  {
    super.setUp()
    
    model = SidebarDataModel(repository: repository, outlineView: outline)
    sbDelegate.model = model
  }
  
  /// Check that root items (except Staging) are groups
  func testGroupItems()
  {
    XCTAssertTrue(repository.createBranch("b1"))
    
    model.roots = model.loadRoots()
    
    for item in model.roots {
      XCTAssertTrue(sbDelegate.outlineView(outline, isGroupItem: item))
    }
  }
  
  func testTags()
  {
    let tagName = "t1"
    guard let headOID = repository.headSHA.flatMap({ repository.oid(forSHA: $0) })
    else {
      XCTFail("no head")
      return
    }
    try! repository.createTag(name: tagName,
                              targetOID: headOID,
                              message: "msg")
    
    model.roots = model.loadRoots()
    
    let tagItem = model.rootItem(.tags).children[0]
    guard let cell = sbDelegate.outlineView(outline, viewFor: nil, item: tagItem)
                     as? NSTableCellView
    else {
      XCTFail("wrong cell type")
      return
    }
    
    XCTAssertEqual(cell.textField?.stringValue, tagName)
  }
  
  func testBranches()
  {
    let branchNames = ["b1", "master"]
    
    XCTAssertTrue(repository.createBranch(branchNames[0]))
    model.roots = model.loadRoots()
    
    for (item, name) in zip(model.rootItem(.branches).children, branchNames) {
      guard let cell = sbDelegate.outlineView(outline, viewFor: nil, item: item)
                       as? NSTableCellView
      else {
        XCTFail("wrong cell type")
        continue
      }
      
      XCTAssertEqual(cell.textField?.stringValue, name)
    }
  }
  
  func testRemotes()
  {
    makeRemoteRepo()
    
    let remoteName = "origin"
    
    XCTAssertNoThrow(try repository.checkOut(branch: "master"))
    XCTAssertTrue(repository.createBranch("b1"))
    XCTAssertNoThrow(
        try repository.addRemote(named: remoteName,
                                 url: URL(fileURLWithPath: remoteRepoPath)))
    
    let configArgs = ["config", "receive.denyCurrentBranch", "ignore"]
    
    XCTAssertNoThrow(try remoteRepository.executeGit(args: configArgs,
                                                     writes: false))
    XCTAssertNoThrow(try repository.push(remote: "origin"))
    
    model.roots = model.loadRoots()
    
    guard let remoteItem = model.rootItem(.remotes).children.first,
          let branchItem = remoteItem.children.first
    else {
      XCTFail("Remote/branch not loaded")
      return
    }
    
    guard let remoteCell = sbDelegate.outlineView(outline, viewFor: nil,
                                                  item: remoteItem)
                           as? NSTableCellView,
          let branchCell = sbDelegate.outlineView(outline, viewFor: nil,
                                                  item: branchItem)
                           as? NSTableCellView
    else {
      XCTFail("Remote/branch cell wrong type")
      return
    }
    
    XCTAssertEqual(remoteCell.textField?.stringValue, remoteName)
    XCTAssertEqual(branchCell.textField?.stringValue, "b1")
  }
}
