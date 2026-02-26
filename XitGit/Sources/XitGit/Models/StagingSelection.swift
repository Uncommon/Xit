import Foundation

/// Staged and unstaged workspace changes
public class StagingSelection: StagedUnstagedSelection
{
  public unowned var repository: any FileChangesRepo
  public var target: SelectionTarget { .staging }
  public var canCommit: Bool { true }
  public var fileList: any FileListModel { indexFileList }
  public var unstagedFileList: any FileListModel { workspaceFileList }

  public let amending: Bool
  
  // Initialization requires a reference to self
  public private(set) var indexFileList: IndexFileList!
  public private(set) var workspaceFileList: WorkspaceFileList!
  
  public init(repository: any FileChangesRepo, amending: Bool)
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
