import Foundation
@testable import Xit

class XTSidebarDataSourceTest: XTTest
{
  var outline = MockSidebarOutline()
  var sbds = XTSideBarDataSource()
  var runLoop: CFRunLoop?

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
    sbds.repository = repository
  }

  /// Check that root items (except Staging) are groups
  func testGroupItems()
  {
    XCTAssertTrue(repository.createBranch("b1"))
    
    sbds.reload()
    waitForRepoQueue()
    
    let count = sbds.outlineView(outline, numberOfChildrenOfItem: nil)
    
    for index in 1..<count {
      let rootItem = sbds.outlineView(outline, child: index, ofItem: nil)
      
      XCTAssertTrue(sbds.outlineView(outline, isGroupItem: rootItem))
    }
  }

  /// Add a tag and make sure it gets loaded correctly
  func testTags()
  {
    try! repository.createTag(name: "t1",
                              targetSHA: repository.headSHA!,
                              message: "msg")
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
  
  /// Add a branch and make sure both branches are loaded correctly
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
  
  /// Create two stashes and check that they are listed
  func testStashes()
  {
    XCTAssertTrue(writeText(toFile1: "second text"))
    try! repository.saveStash(name: "s1", includeUntracked: false)
    XCTAssertTrue(writeText(toFile1: "third text"))
    try! repository.saveStash(name: "s2", includeUntracked: false)
    
    sbds.reload()
    waitForRepoQueue()
    
    let stashes = groupItem(.stashes)
    let stashCount = sbds.outlineView(outline, numberOfChildrenOfItem: stashes)
    
    XCTAssertEqual(stashCount, 2)
  }
  
  /// Check that a remote and its branches are displayed correctly
  func testRemotes()
  {
    makeRemoteRepo()
    
    let remoteName = "origin"
    
    XCTAssertNoThrow(try repository.checkout(branch: "master"))
    XCTAssertTrue(repository.createBranch("b1"))
    XCTAssertNoThrow(
        try repository.add(remote: remoteName,
                           url: URL(fileURLWithPath: remoteRepoPath)))
    
    let configArgs = ["config", "receive.denyCurrentBranch", "ignore"]
    
    _ = try! remoteRepository.executeGit(args: configArgs, writes: false)
    try! repository.push(remote: "origin")
    
    sbds.reload()
    waitForRepoQueue()
    
    let remotes = groupItem(.remotes)
    let remoteCount = sbds.outlineView(outline, numberOfChildrenOfItem: remotes)
    
    XCTAssertEqual(remoteCount, 1)
    
    let remote = sbds.outlineView(outline, child: 0, ofItem: remotes)
    let remoteView = sbds.outlineView(outline, viewFor: nil, item: remote)
                     as! NSTableCellView
    
    XCTAssertEqual(remoteView.textField!.stringValue, remoteName)
    
    let branchCount = sbds.outlineView(outline, numberOfChildrenOfItem: remote)
    
    XCTAssertEqual(branchCount, 2)
    
    let branchNames = ["b1", "master"]
    
    for (index, branchName) in branchNames.enumerated() {
      let branch = sbds.outlineView(outline, child: index, ofItem: remote)
      let expandable = sbds.outlineView(outline, isItemExpandable: branch)
      
      XCTAssertFalse(expandable)
      
      let branchView = sbds.outlineView(outline, viewFor: nil, item: branch)
                       as! NSTableCellView
      let itemName = branchView.textField!.stringValue
      
      XCTAssertEqual(itemName, branchName)
    }
  }
  
  func testSubmodules()
  {
    let repoParentPath = (repoPath as NSString).deletingLastPathComponent
    let sub1Path = repoParentPath.appending(pathComponent: "repo1")
    let sub2Path = repoParentPath.appending(pathComponent: "repo2")
    let sub1 = createRepo(sub1Path)!
    let sub2 = createRepo(sub2Path)!
    
    _ = [sub1, sub2].map {
      self.commit(newTextFile: file1Name, content: "text", repository: $0)
    }
  
    XCTAssertNoThrow(try repository.addSubmodule(path: "sub1", url: "../repo1"))
    XCTAssertNoThrow(try repository.addSubmodule(path: "sub2", url: "../repo2"))
    guard repository.submodules().count == 2
    else { return }
    
    sbds.reload()
    waitForRepoQueue()
    
    let subs = groupItem(.submodules)
    let subCount = sbds.outlineView(outline, numberOfChildrenOfItem: subs)
    
    XCTAssertEqual(subCount, 2)
    
    let subData = [("sub1", "../repo1"),
                   ("sub2", "../repo2")]
    
    for (index, data) in subData.enumerated() {
      let subItem = sbds.outlineView(outline, child: index, ofItem: subs)
                    as! XTSubmoduleItem
      
      XCTAssertEqual(subItem.submodule.name, data.0)
      XCTAssertEqual(subItem.submodule.URLString, data.1)
    }
  }
  
  /// Create a branch and make sure the sidebar notices it
  func testReload()
  {
    let changeObserver = NotificationCenter.default.addObserver(
          forName: .XTRepositoryChanged, object: repository, queue: nil) {
      (_) in
      self.runLoop.map { CFRunLoopStop($0) }
    }
    
    defer {
      NotificationCenter.default.removeObserver(changeObserver)
    }
    
    XCTAssertTrue(repository.createBranch("b1"))
    
    let expectedTitles = ["b1", "master"]
    var titles = [String]()
    let maxTries = 5
    
    for _ in 0..<maxTries {
      runLoop = CFRunLoopGetCurrent()
      if !CFRunLoopRunWithTimeout(5) {
        NSLog("warning: Timeout on reload")
      }
      runLoop = nil
      
      let branches = groupItem(.branches)
      
      titles = branches.children.map { $0.title }
      if titles == expectedTitles {
        break
      }
    }
    XCTAssertEqual(titles, expectedTitles)
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
