import Foundation

enum SpecialOID: OID
{
  case staging

  var isZero: Bool { false }
  var sha: String { "" }
}

/// Staged and unstaged workspace changes
class StagingSelection: StagedUnstagedSelection
{
  unowned var repository: any FileChangesRepo
  var oidToSelect: (any OID)? { SpecialOID.staging }
  var canCommit: Bool { true }
  var fileList: any FileListModel { indexFileList }
  var unstagedFileList: any FileListModel { workspaceFileList }

  let amending: Bool
  
  // Initialization requires a reference to self
  fileprivate(set) var indexFileList: IndexFileList!
  fileprivate(set) var workspaceFileList: WorkspaceFileList!
  
  init(repository: any FileChangesRepo, amending: Bool)
  {
    self.repository = repository
    self.amending = amending
    
    if amending {
      indexFileList = AmendingIndexFileList(repository: repository)
      workspaceFileList = WorkspaceFileList(repository: repository)
    }
    else {
      indexFileList = IndexFileList(repository: repository)
      workspaceFileList = WorkspaceFileList(repository: repository)
    }
  }
}
