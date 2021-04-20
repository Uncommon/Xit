import XCTest
@testable import Xit

class FakeRepoUIController: RepositoryUIController
{
  var repoController: GitRepositoryController!
  var repository: Repository

  var selectedCommitSHA: String = ""
  var selection: RepositorySelection? = nil
  var isAmending = false

  init(repository: Repository)
  {
    self.repository = repository
  }
  
  func select(sha: String) {}
  func showErrorMessage(error: RepoError) {}
  func updateForFocus() {}
  func postIndexNotification() {}
}

class FileListDataSourceTest: XTTest
{
  func testHistoricFileList() throws
  {
    let text = "some text"
    
    for n in 0..<10 {
      let fileName = "file_\(n).txt"

      try execute(in: repository) {
        CommitFiles("commit") {
          Write(text, to: fileName)
        }
      }
    }
  
    let outlineView = NSOutlineView.init()
    let repoUIController = FakeRepoUIController(repository: repository)
    let flds = FileTreeDataSource(useWorkspaceList: false)
    var expectedCount = 11
    let history = CommitHistory<GitOID>()
    
    repoUIController.repoController = GitRepositoryController(repository: repository)
    history.repository = repository
    objc_sync_enter(flds)
    flds.repoUIController = repoUIController
    objc_sync_exit(flds)
    waitForRepoQueue()
    
    for entry in history.entries {
      repoUIController.selection = CommitSelection(repository: repository,
                                                 commit: entry.commit)
      flds.reload()
      waitForRepoQueue()
    
      let fileCount = flds.outlineView(outlineView, numberOfChildrenOfItem: nil)
    
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
  
  func testMulipleFileList() throws
  {
    let text = "some text"
    
    #if swift(>=5.4) // needs for loop support
    try execute(in: repository) {
      CommitFiles {
        Delete(.file1)
        for n in 0..<12 {
          Write(text, to: "dir_\(n%2)/subdir_\(n%3)/file_\(n).txt")
        }
      }
    }
    #else
    for i in 0..<2 {
      for j in 0..<3 {
        let path = "dir_\(i)/subdir_\(j)"
        let fullPath = repoPath +/ path

        try FileManager.default.createDirectory(atPath: fullPath,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
      }
    }
    try FileManager.default.removeItem(atPath: file1Path)

    for n in 0..<12 {
      let file = "\(repoPath!)/dir_\(n%2)/subdir_\(n%3)/file_\(n).txt"
      
      try text.write(toFile: file, atomically: true, encoding: .ascii)
    }
    try repository.stageAllFiles()
    _ = try repository.commit(message: "commit", amend: false)
    #endif
    
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
                                               numberOfChildrenOfItem: nil) == 3 },
                       timeout: 1.0),
                  "reload not completed")
    
    for rootIndex in 0..<2 {
      let root = flds.outlineView(outlineView, child: rootIndex, ofItem: nil)
      let fileCount = flds.outlineView(outlineView, numberOfChildrenOfItem: root)
      
      XCTAssertEqual(fileCount, 3, "item \(rootIndex)")
    }
  }
}
