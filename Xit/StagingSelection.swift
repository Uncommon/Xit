import Foundation

/// Staged and unstaged workspace changes
class StagingSelection: StagedUnstagedSelection
{
  unowned var repository: FileChangesRepo
  var shaToSelect: String? { return XTStagingSHA }
  var canCommit: Bool { return true }
  var fileList: FileListModel { return indexFileList }
  var unstagedFileList: FileListModel { return workspaceFileList }
  
  // Initialization requires a reference to self
  private(set) var indexFileList: IndexFileList!
  private(set) var workspaceFileList: WorkspaceFileList!
  
  init(repository: FileChangesRepo)
  {
    self.repository = repository
    
    indexFileList = IndexFileList(selection: self)
    workspaceFileList = WorkspaceFileList(selection: self)
  }
}

/// Base class to consodidate the selection reference for FileListModel
class StagingListModel
{
  unowned let selection: RepositorySelection
  
  init(selection: StagingSelection)
  {
    self.selection = selection
  }
}

/// File list for staged files (the index)
class IndexFileList: StagingListModel, FileListModel
{
  var stagingType: StagingType { return .index }
  
  var changes: [FileChange] { return repository.stagedChanges() }
  
  func diffForFile(_ path: String) -> PatchMaker.PatchResult?
  {
    return repository.stagedDiff(file: path)
  }

  func dataForFile(_ path: String) -> Data?
  {
    return repository.contentsOfStagedFile(path: path)
  }

  func blame(for path: String) -> Blame?
  {
    guard let data = repository.contentsOfStagedFile(path: path)
    else { return nil }
    
    return repository.blame(for: path, data: data, to: nil)
  }
  
  func treeRoot(oldTree: NSTreeNode?) -> NSTreeNode
  {
    let builder = WorkspaceTreeBuilder(changes: repository.workspaceStatus)
    let root = builder.build(repository.repoURL)
    
    postProcess(fileTree: root)
    return root
  }

  func fileURL(_ path: String) -> URL? { return nil }
}

/// File list for unstaged files (the workspace)
class WorkspaceFileList: StagingListModel, FileListModel
{
  var stagingType: StagingType { return .workspace }

  var changes: [FileChange] { return repository.unstagedChanges() }
  
  func diffForFile(_ path: String) -> PatchMaker.PatchResult?
  {
    return repository.unstagedDiff(file: path)
  }

  func dataForFile(_ path: String) -> Data?
  {
    let url = repository.fileURL(path)
    
    return try? Data(contentsOf: url)
  }

  func blame(for path: String) -> Blame?
  {
    return repository.blame(for: path, from: nil, to: nil)
  }
  
  func fileURL(_ path: String) -> URL?
  {
    return repository.fileURL(path)
  }
  
  func treeRoot(oldTree: NSTreeNode?) -> NSTreeNode
  {
    let builder = WorkspaceTreeBuilder(changes: repository.workspaceStatus)
    let root = builder.build(repository.repoURL)
    
    postProcess(fileTree: root)
    return root
  }
}
