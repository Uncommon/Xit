import Foundation
import XCTest
@testable import Xit

class XTFileChangesDataSourceTest: XTTest
{
  func testInitialCommit()
  {
    let repoUIController = FakeRepoUIController(repository: repository)
    let dataSource = FileChangesDataSource(useWorkspaceList: false)
    let outlineView = NSOutlineView()
    let headCommit = GitCommit(sha: repository.headSHA!,
                               repository: repository.gitRepo)!
    
    repoUIController.selection = CommitSelection(repository: repository,
                                                 commit: headCommit)
    objc_sync_enter(dataSource)
    dataSource.repoUIController = repoUIController
    objc_sync_exit(dataSource)
    outlineView.dataSource = dataSource
    dataSource.reload()
    waitForRepoQueue()
    WaitForQueue(DispatchQueue.main)
    
    XCTAssertEqual(dataSource.outlineView(outlineView,
                                          numberOfChildrenOfItem: nil),
                   1)
    
    let item1 = dataSource.outlineView(outlineView, child: 0, ofItem: nil)
    
    XCTAssertEqual(dataSource.path(for: item1), FileName.file1)
    XCTAssertFalse(dataSource.outlineView(outlineView, isItemExpandable: item1))
    XCTAssertEqual(dataSource.change(for: item1), DeltaStatus.added)
  }
}
