import Foundation

/// Base class to consodidate the selection reference for FileListModel
public class StagingListModel
{
  public unowned let repository: any FileChangesRepo

  public init(repository: any FileChangesRepo)
  {
    self.repository = repository
  }
}

/// File list for staged files (the index)
public class IndexFileList: StagingListModel, FileListModel
{
  public var changes: [FileChange]
  {
    Signpost.interval(.loadIndex) {
      repository.stagedChanges()
    }
  }

  public func equals(_ other: any FileListModel) -> Bool
  {
    other is IndexFileList
  }
  
  public func diffForFile(_ path: String) -> PatchMaker.PatchResult?
  {
    return repository.stagedDiff(file: path)
  }
  
  public func dataForFile(_ path: String) -> Data?
  {
    return repository.contentsOfStagedFile(path: path)
  }
  
  public func blame(for path: String) -> (any Blame)?
  {
    guard let data = repository.contentsOfStagedFile(path: path)
    else { return nil }
    
    return repository.blame(for: path, data: data, to: nil)
  }
  
  public func treeRoot(oldTree: FileChangeNode?) -> FileChangeNode
  {
    return treeRoot(changes: repository.stagedChanges(), oldTree: oldTree)
  }
  
  func treeRoot(changes: [FileChange], oldTree: FileChangeNode?) -> FileChangeNode
  {
    let builder = WorkspaceTreeBuilder(fileChanges: changes)
    let root = builder.build(repository.repoURL)
    
    for stagedChange in changes {
      var stagedChange = stagedChange
      stagedChange.path = stagedChange.path.withPrefix(FileChangeNode.rootPrefix)
      if let node = root.fileChangeNode(path: stagedChange.path) {
        node.value.status = stagedChange.status
      }
      else {
        root.add(fileChange: stagedChange)
      }
    }
    
    postProcess(fileTree: root)
    return root
  }
  
  public func fileURL(_ path: String) -> URL? { return nil }
}

/// Index file list with Amend turned on
public final class AmendingIndexFileList: IndexFileList
{
  public override var changes: [FileChange]
  { repository.amendingStagedChanges() }
  
  public override func diffForFile(_ path: String) -> PatchMaker.PatchResult?
  {
    repository.amendingStagedDiff(file: path)
  }
  
  public override func treeRoot(oldTree: FileChangeNode?) -> FileChangeNode
  {
    treeRoot(changes: repository.amendingStagedChanges(), oldTree: oldTree)
  }
}

/// File list for unstaged files (the workspace)
public final class WorkspaceFileList: StagingListModel, FileListModel
{
  public var showingIgnored = false
  
  public var changes: [FileChange]
  {
    Signpost.interval(.loadWorkspace) {
      repository.unstagedChanges(showIgnored: showingIgnored)
    }
  }

  public func equals(_ other: any FileListModel) -> Bool
  {
    other is WorkspaceFileList
  }
  
  public func diffForFile(_ path: String) -> PatchMaker.PatchResult?
  {
    repository.unstagedDiff(file: path)
  }
  
  public func dataForFile(_ path: String) -> Data?
  {
    let url = repository.fileURL(path)
    
    return try? Data(contentsOf: url)
  }
  
  public func blame(for path: String) -> (any Blame)?
  {
    repository.blame(for: path, from: nil, to: nil)
  }
  
  public func fileURL(_ path: String) -> URL?
  {
    repository.fileURL(path)
  }
  
  public func treeRoot(oldTree: FileChangeNode?) -> FileChangeNode
  {
    let builder = WorkspaceTreeBuilder(fileChanges: repository.unstagedChanges(),
                                       repo: showingIgnored ? nil : repository)
    let root = builder.build(repository.repoURL)
    
    postProcess(fileTree: root)
    return root
  }
}
