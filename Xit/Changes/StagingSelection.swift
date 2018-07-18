import Foundation

/// Fake SHA value for selecting staging view.
let XTStagingSHA = ""

/// Staged and unstaged workspace changes
class StagingSelection: StagedUnstagedSelection
{
  unowned var repository: FileChangesRepo
  var shaToSelect: String? { return XTStagingSHA }
  var canCommit: Bool { return true }
  var fileList: FileListModel { return indexFileList }
  var unstagedFileList: FileListModel { return workspaceFileList }
  
  // Initialization requires a reference to self
  fileprivate(set) var indexFileList: IndexFileList!
  fileprivate(set) var workspaceFileList: WorkspaceFileList!
  
  init(repository: FileChangesRepo)
  {
    self.repository = repository
    
    setFileLists()
  }
  
  func setFileLists()
  {
    indexFileList = IndexFileList(selection: self)
    workspaceFileList = WorkspaceFileList(selection: self)
  }
}

/// Staging selection with Amend turned on
class AmendingSelection: StagingSelection
{
  override func setFileLists()
  {
    indexFileList = AmendingIndexFileList(selection: self)
    workspaceFileList = WorkspaceFileList(selection: self)
  }
}
