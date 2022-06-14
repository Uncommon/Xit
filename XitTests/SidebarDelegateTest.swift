import Foundation
import XCTest
@testable import Xit

@MainActor
class SidebarDelegateTest: XTTest
{
  var outline = MockSidebarOutline()
  let sbDelegate = SidebarDelegate()
  var model: SidebarDataModel!
  
  @MainActor
  override func setUp()
  {
    super.setUp()
    
    model = SidebarDataModel(repository: repository, outlineView: outline)
    sbDelegate.model = model
  }
  
  /// Check that root items (except Staging) are groups
  func testGroupItems() throws
  {
    try execute(in: repository) {
      CreateBranch("b1")
    }

    model.reload()

    for item in model.roots {
      XCTAssertTrue(sbDelegate.outlineView(outline, isGroupItem: item))
    }
  }
  
  func testTags() throws
  {
    let tagName = "t1"
    guard let headOID = repository.headSHA.flatMap({ repository.oid(forSHA: $0) })
    else {
      XCTFail("no head")
      return
    }
    try repository.createTag(name: tagName, targetOID: headOID, message: "msg")
    
    model.reload()

    let tagItem = model.rootItem(.tags).children[0]
    guard let cell = sbDelegate.outlineView(outline, viewFor: nil, item: tagItem)
                     as? NSTableCellView
    else {
      XCTFail("wrong cell type")
      return
    }
    
    XCTAssertEqual(cell.textField?.stringValue, tagName)
  }
  
  func testBranches() throws
  {
    let branchNames = ["b1", "master"]
    
    try execute(in: repository) {
      CreateBranch("b1")
    }
    model.reload()

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
  
  func testRemotes() throws
  {
    makeRemoteRepo()
    
    let remoteName = "origin"

    try execute(in: repository) {
      CheckOut(branch: "master")
      CreateBranch("b1")
    }
    try repository.addRemote(named: remoteName,
                             url: URL(fileURLWithPath: remoteRepoPath))
    
    let configArgs = ["config", "receive.denyCurrentBranch", "ignore"]
    
    _ = try remoteRepository.executeGit(args: configArgs, writes: false)
    try repository.push(remote: "origin")
    
    model.reload()

    let remoteItem = try XCTUnwrap(model.rootItem(.remotes).children.first)
    let branchItem = try XCTUnwrap(remoteItem.children.first)
    
    let remoteCell = try XCTUnwrap(sbDelegate.outlineView(outline, viewFor: nil,
                                                          item: remoteItem)
                                   as? NSTableCellView)
    let branchCell = try XCTUnwrap(sbDelegate.outlineView(outline, viewFor: nil,
                                                          item: branchItem)
                                   as? NSTableCellView)
    
    XCTAssertEqual(remoteCell.textField?.stringValue, remoteName)
    XCTAssertEqual(branchCell.textField?.stringValue, "b1")
  }
}
