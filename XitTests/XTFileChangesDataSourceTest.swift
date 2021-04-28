import Foundation
import XCTest
@testable import Xit

class XTFileChangesDataSourceTest: XTTest
{
  func testInitialCommit() throws
  {
    let repoUIController = FakeRepoUIController(repository: repository)
    let dataSource = FileChangesDataSource(useWorkspaceList: false)
    let outlineView = NSOutlineView()
    let headSHA = try XCTUnwrap(repository.headSHA)
    let headCommit = try XCTUnwrap(GitCommit(sha: headSHA, repository: repository.gitRepo))
    
    repoUIController.repoController = GitRepositoryController(repository: repository)
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
    
    XCTAssertEqual(dataSource.path(for: item1), TestFileName.file1.rawValue)
    XCTAssertFalse(dataSource.outlineView(outlineView, isItemExpandable: item1))
    XCTAssertEqual(dataSource.change(for: item1), DeltaStatus.added)
  }
}
