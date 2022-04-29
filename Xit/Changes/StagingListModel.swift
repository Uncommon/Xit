import Foundation

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
  var changes: [FileChange]
  {
    Signpost.interval(.loadIndex) {
      repository.stagedChanges()
    }
  }
  
  func diffForFile(_ path: String) -> PatchMaker.PatchResult?
  {
    return repository.stagedDiff(file: path)
  }
  
  func dataForFile(_ path: String) -> Data?
  {
    return repository.contentsOfStagedFile(path: path)
  }
  
  func blame(for path: String) -> (any Blame)?
  {
    guard let data = repository.contentsOfStagedFile(path: path)
    else { return nil }
    
    return repository.blame(for: path, data: data, to: nil)
  }
  
  func treeRoot(oldTree: NSTreeNode?) -> NSTreeNode
  {
    return treeRoot(changes: repository.stagedChanges(), oldTree: oldTree)
  }
  
  func treeRoot(changes: [FileChange], oldTree: NSTreeNode?) -> NSTreeNode
  {
    let builder = WorkspaceTreeBuilder(fileChanges: changes)
    let root = builder.build(repository.repoURL)
    
    for stagedChange in changes {
      stagedChange.path = stagedChange.path.withPrefix(NSTreeNode.rootPrefix)
      if let node = root.fileChangeNode(path: stagedChange.path) {
        node.fileChange.status = stagedChange.status
      }
      else {
        root.add(fileChange: stagedChange)
      }
    }
    
    postProcess(fileTree: root)
    return root
  }
  
  func fileURL(_ path: String) -> URL? { return nil }
}

/// Index file list with Amend turned on
final class AmendingIndexFileList: IndexFileList
{
  override var changes: [FileChange]
  { repository.amendingStagedChanges() }
  
  override func diffForFile(_ path: String) -> PatchMaker.PatchResult?
  {
    return repository.amendingStagedDiff(file: path)
  }
  
  override func treeRoot(oldTree: NSTreeNode?) -> NSTreeNode
  {
    return treeRoot(changes: repository.amendingStagedChanges(),
                    oldTree: oldTree)
  }
}

/// File list for unstaged files (the workspace)
final class WorkspaceFileList: StagingListModel, FileListModel
{
  var showingIgnored = false
  
  var changes: [FileChange]
  {
    Signpost.interval(.loadWorkspace) {
      repository.unstagedChanges(showIgnored: showingIgnored)
    }
  }
  
  func diffForFile(_ path: String) -> PatchMaker.PatchResult?
  {
    return repository.unstagedDiff(file: path)
  }
  
  func dataForFile(_ path: String) -> Data?
  {
    let url = repository.fileURL(path)
    
    return try? Data(contentsOf: url)
  }
  
  func blame(for path: String) -> (any Blame)?
  {
    return repository.blame(for: path, from: nil, to: nil)
  }
  
  func fileURL(_ path: String) -> URL?
  {
    return repository.fileURL(path)
  }
  
  func treeRoot(oldTree: NSTreeNode?) -> NSTreeNode
  {
    let builder = WorkspaceTreeBuilder(fileChanges: repository.unstagedChanges(),
                                       repo: showingIgnored ? nil : repository)
    let root = builder.build(repository.repoURL)
    
    postProcess(fileTree: root)
    return root
  }
}
