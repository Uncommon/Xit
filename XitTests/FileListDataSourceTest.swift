import XCTest
@testable import Xit

class FakeRepoController: RepositoryController
{
  var queue = TaskQueue(id: "test")
  
  var selectedCommitSHA: String = ""
  var selectedModel: FileChangesModel? = nil
  var isAmending = false
  
  func select(sha: String) {}
  func showErrorMessage(error: XTRepository.Error) {}
}

class FileListDataSourceTest: XTTest
{
  func testHistoricFileList()
  {
    let text = "some text"
    
    for n in 0..<10 {
      let fileName = "file_\(n).txt"
      let filePath = repoPath.appending(pathComponent: fileName)
      
      try! text.write(toFile: filePath, atomically: true, encoding: .ascii)
      try! repository.stageAllFiles()
      try! repository.commit(message: "commit", amend: false,
                             outputBlock: nil)
    }
  
    let outlineView = NSOutlineView.init()
    let repoController = FakeRepoController()
    let flds = FileTreeDataSource()
    var expectedCount = 11
    let history = XTCommitHistory<GitOID>()
    
    history.repository = repository
    objc_sync_enter(flds)
    flds.taskQueue = repository.queue
    flds.repoController = repoController
    objc_sync_exit(flds)
    waitForRepoQueue()
    
    for entry in history.entries {
      repoController.selectedModel = CommitChanges(repository: repository,
                                                   commit: entry.commit)
      flds.reload()
      waitForRepoQueue()
    
      let fileCount = flds.outlineView(outlineView, numberOfChildrenOfItem: nil)
    
      XCTAssertEqual(fileCount, expectedCount, "file count")
      expectedCount -= 1
    }
  }
  
  func testMulipleFileList()
  {
    let text = "some text"
    
    for i in 0..<2 {
      for j in 0..<3 {
        let path = "dir_\(i)/subdir_\(j)"
        let fullPath = repoPath.appending(pathComponent: path)
        
        try! FileManager.default.createDirectory(atPath: fullPath,
                                                 withIntermediateDirectories: true,
                                                 attributes: nil)
      }
    }
    try! FileManager.default.removeItem(atPath: file1Path)
    
    for n in 0..<12 {
      let file = "\(repoPath)/dir_\(n%2)/subdir_\(n%3)/file_\(n).txt"
      
      try! text.write(toFile: file, atomically: true, encoding: .ascii)
    }
    try! repository.stageAllFiles()
    _ = try! repository.commit(message: "commit", amend: false,
                               outputBlock: nil)
    
    let repoController = FakeRepoController()
    let headCommit = XTCommit(sha: repository.headSHA!, repository: repository)!
    
    repoController.selectedModel = CommitChanges(repository: repository,
                                                 commit: headCommit)
    
    let outlineView = NSOutlineView()
    let flds = FileTreeDataSource()
    
    objc_sync_enter(flds)
    flds.repoController = repoController
    flds.taskQueue = repository.queue
    flds.observe(repository: repository)
    objc_sync_exit(flds)
    waitForRepoQueue()
    
    let fileCount = flds.outlineView(outlineView, numberOfChildrenOfItem: nil)
    
    XCTAssertEqual(fileCount, 3)
    
    for rootIndex in 0..<2 {
      let root = flds.outlineView(outlineView, child: rootIndex, ofItem: nil)
      let fileCount = flds.outlineView(outlineView, numberOfChildrenOfItem: root)
      
      XCTAssertEqual(fileCount, 3, "item \(rootIndex)")
    }
  }
}
