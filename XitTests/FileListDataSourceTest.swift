import XCTest
import Combine
@testable import Xit
@testable import XitGit
import XitGitTestSupport

class FakeRepoUIController: RepositoryUIController
{
  let reselectPublisher: AnyPublisher<Void, Never> = Just(()).eraseToAnyPublisher()

  var selectionPublisher: AnyPublisher<RepositorySelection?, Never>
  { Just(nil).eraseToAnyPublisher() }

  var repoController: GitRepositoryController!
  var repository: any FullRepository

  var selectedCommitSHA: String = ""
  var selection: (any RepositorySelection)? = nil
  var isAmending = false

  init(repository: any FullRepository)
  {
    self.repository = repository
  }
  
  func select(oid: GitOID) {}
  func reselect() {}
  func showErrorMessage(error: RepoError) {}
  func updateForFocus() {}
  func postIndexNotification() {}
}

class FileListDataSourceTest: XTTest
{
  @MainActor
  func testHistoricFileList() throws
  {
    try execute(in: repository) {
      for n in 0..<10 {
        CommitFiles {
          Write("some text", to: "file_\(n).txt")
        }
      }
    }
  
    let outlineView = NSOutlineView.init()
    let repoUIController = FakeRepoUIController(repository: repository)
    let ftds = FileTreeDataSource(useWorkspaceList: false)
    var expectedCount = 11
    let history = CommitHistory<GitCommit>()
    
    repoUIController.repoController = GitRepositoryController(repository: repository)
    history.repository = repository
    objc_sync_enter(ftds)
    ftds.repoUIController = repoUIController
    objc_sync_exit(ftds)
    waitForRepoQueue()
    
    for entry in history.entries {
      repoUIController.selection = CommitSelection(repository: repository,
                                                 commit: entry.commit)
      ftds.reload()
      waitForRepoQueue()
    
      let fileCount = ftds.outlineView(outlineView, numberOfChildrenOfItem: nil)
    
      XCTAssertEqual(fileCount, expectedCount, "file count")
      expectedCount -= 1
    }
  }
  
  func wait(for condition: () -> Bool, timeout: TimeInterval) -> Bool
  {
    let deadline = CFAbsoluteTimeGetCurrent() + timeout
    
    while !condition() && CFAbsoluteTimeGetCurrent() < deadline {
      CFRunLoopRunWithTimeout(0.25)
    }
    return CFAbsoluteTimeGetCurrent() < deadline
  }
  
  @MainActor
  func testMulipleFileList() throws
  {
    let text = "some text"
    
    try execute(in: repository) {
      CommitFiles {
        Delete(.file1)
        for n in 0..<12 {
          Write(text, to: "dir_\(n%2)/subdir_\(n%3)/file_\(n).txt")
        }
      }
    }
    
    let repoUIController = FakeRepoUIController(repository: repository)
    let headSHA = try XCTUnwrap(repository.headSHA)
    let headCommit = GitCommit(sha: headSHA,
                               repository: repository.gitRepo)!
    
    repoUIController.repoController = GitRepositoryController(repository: repository)
    repoUIController.selection = CommitSelection(repository: repository,
                                                 commit: headCommit)
    
    let outlineView = NSOutlineView()
    let flds = FileTreeDataSource(useWorkspaceList: false)
    
    objc_sync_enter(flds)
    flds.repoUIController = repoUIController
    objc_sync_exit(flds)
    waitForRepoQueue()

    XCTAssertTrue(wait(for: { flds.outlineView(outlineView,
                                               numberOfChildrenOfItem: nil) == 2 },
                       timeout: 1.0),
                  "reload not completed")
    
    for rootIndex in 0..<2 {
      let root = flds.outlineView(outlineView, child: rootIndex, ofItem: nil)
      let fileCount = flds.outlineView(outlineView, numberOfChildrenOfItem: root)
      
      XCTAssertEqual(fileCount, 3, "item \(rootIndex)")
    }
  }
}
