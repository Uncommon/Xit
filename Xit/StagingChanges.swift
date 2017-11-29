import Foundation

/// Staged and unstaged workspace changes
class StagingChanges: FileChangesModel
{
  unowned var repository: FileChangesRepo
  var shaToSelect: String? { return XTStagingSHA }
  var hasUnstaged: Bool { return true }
  var canCommit: Bool { return true }
  var changes: [FileChange]
  { return repository.changes(for: XTStagingSHA, parent: nil) }
  
  init(repository: FileChangesRepo)
  {
    self.repository = repository
  }
  
  func treeRoot(oldTree: NSTreeNode?) -> NSTreeNode
  {
    let builder = WorkspaceTreeBuilder(changes: repository.workspaceStatus)
    let root = builder.build(repository.repoURL)
    
    postProcess(fileTree: root)
    return root
  }
  
  func diffForFile(_ path: String, staged: Bool) -> PatchMaker.PatchResult?
  {
    if staged {
      return repository.stagedDiff(file: path)
    }
    else {
      return repository.unstagedDiff(file: path)
    }
  }
  
  func blame(for path: String, staged: Bool) -> Blame?
  {
    if staged {
      guard let data = repository.contentsOfStagedFile(path: path)
      else { return nil }
      
      return repository.blame(for: path, data: data, to: nil)
    }
    else {
      return repository.blame(for: path, from: nil, to: nil)
    }
  }
  
  func dataForFile(_ path: String, staged: Bool) -> Data?
  {
    if staged {
      return repository.contentsOfStagedFile(path: path)
    }
    else {
      let url = repository.fileURL(path)
      
      return try? Data(contentsOf: url)
    }
  }
  
  func unstagedFileURL(_ path: String) -> URL?
  {
    return repository.fileURL(path)
  }
}
