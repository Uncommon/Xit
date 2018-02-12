import Foundation
@testable import Xit

class XTFileChangesDataSourceTest: XTTest
{
  func testInitialCommit()
  {
    let repoController = FakeRepoController(repository: repository)
    let dataSource = FileChangesDataSource()
    let outlineView = NSOutlineView()
    let headCommit = XTCommit(sha: repository.headSHA!, repository: repository)!
    
    repoController.selection = CommitSelection(repository: repository,
                                                 commit: headCommit)
    objc_sync_enter(dataSource)
    dataSource.repoController = repoController
    objc_sync_exit(dataSource)
    outlineView.dataSource = dataSource
    dataSource.reload()
    waitForRepoQueue()
    WaitForQueue(DispatchQueue.main)
    
    XCTAssertEqual(dataSource.outlineView(outlineView,
                                          numberOfChildrenOfItem: nil),
                   1)
    
    let item1 = dataSource.outlineView(outlineView, child: 0, ofItem: nil)
    
    XCTAssertEqual(dataSource.path(for: item1), "file1.txt")
    XCTAssertFalse(dataSource.outlineView(outlineView, isItemExpandable: item1))
    XCTAssertEqual(dataSource.change(for: item1), DeltaStatus.added)
  }
}
