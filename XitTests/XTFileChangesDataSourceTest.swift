import Foundation
@testable import Xit

class XTFileChangesDataSourceTest: XTTest
{
  func testInitialCommit()
  {
    let repoController = FakeRepoController()
    let dataSource = XTFileChangesDataSource()
    let outlineView = NSOutlineView()
    
    repoController.selectedModel = CommitChanges(repository: repository,
                                                 sha: repository.headSHA!)
    dataSource.repository = repository
    dataSource.repoController = repoController
    outlineView.dataSource = dataSource
    dataSource.reload()
    waitForRepoQueue()
    WaitForQueue(DispatchQueue.main)
    
    XCTAssertEqual(dataSource.outlineView(outlineView, numberOfChildrenOfItem: nil), 1)
    
    let item1 = dataSource.outlineView(outlineView, child: 0, ofItem: nil)
    
    XCTAssertEqual(dataSource.path(for: item1), "file1.txt")
    XCTAssertFalse(dataSource.outlineView(outlineView, isItemExpandable: item1))
    XCTAssertEqual(dataSource.change(for: item1), XitChange.added)
  }
}
