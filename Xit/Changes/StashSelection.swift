import Foundation

/// Changes for a selected stash, merging workspace, index, and untracked
class StashSelection: StagedUnstagedSelection
{
  unowned var repository: FileChangesRepo
  let stash: Stash
  var canCommit: Bool { false }
  var shaToSelect: String? { stash.mainCommit?.parentSHAs[0] }
  var fileList: FileListModel { stagedList }
  var unstagedFileList: FileListModel { unstagedList }
  
  // Initialization requires a reference to self
  private(set) var stagedList: StashStagedList! = nil
  private(set) var unstagedList: StashUnstagedList! = nil
  
  convenience init(repository: FileChangesRepo & Stashing, index: UInt)
  {
    self.init(repository: repository,
              stash: repository.stash(index: index, message: nil))
  }
  
  init(repository: FileChangesRepo, stash: Stash)
  {
    self.repository = repository
    self.stash = stash
    
    stagedList = StashStagedList(selection: self)
    unstagedList = StashUnstagedList(selection: self)
  }
}

/// Base class for stash file lists
class StashFileList
{
  weak var stashSelection: StashSelection!
  var selection: RepositorySelection { stashSelection }
  
  let mainSelection: CommitSelection?
  let mainList: CommitFileList?

  var stash: Stash { stashSelection.stash }
  
  init(selection: StashSelection)
  {
    self.stashSelection = selection
    self.mainSelection = selection.stash.mainCommit.map {
        CommitSelection(repository: selection.repository, commit: $0) }
    self.mainList = mainSelection.map { CommitFileList(selection: $0) }
  }
}

/// File list for the staged portion of a stash
class StashStagedList: StashFileList, FileListModel
{
  var stagingType: StagingType { .none }
  
  let indexSelection: CommitSelection?
  let indexList: CommitFileList?
  
  var changes: [FileChange]
  {
    stash.indexCommit.map {
      repository.changes(for: $0.sha, parent: nil)
    } ?? []
  }

  override init(selection: StashSelection)
  {
    self.indexSelection = selection.stash.indexCommit.map {
        CommitSelection(repository: selection.repository, commit: $0) }
    self.indexList = indexSelection.map { CommitFileList(selection: $0) }

    super.init(selection: selection)
  }
  
  func treeRoot(oldTree: NSTreeNode?) -> NSTreeNode
  {
    return indexList?.treeRoot(oldTree: oldTree) ?? NSTreeNode()
  }
  
  func diffForFile(_ path: String) -> PatchMaker.PatchResult?
  {
    return stash.stagedDiffForFile(path)
  }
  
  func dataForFile(_ path: String) -> Data?
  {
    guard let indexCommit = stash.indexCommit
    else { return nil }
    
    return repository.contentsOfFile(path: path, at: indexCommit)
  }

  func blame(for path: String) -> Blame?
  {
    guard let indexCommit = stash.indexCommit
    else { return nil }
    
    return repository.blame(for: path, from: indexCommit.oid, to: nil)
  }

  func fileURL(_ path: String) -> URL?
  {
    return nil
  }
}

/// File list for the unstaged portion of a stash
class StashUnstagedList: StashFileList, FileListModel
{
  var stagingType: StagingType { .none }

  var changes: [FileChange] { stash.workspaceChanges() }
  
  let untrackedSelection: CommitSelection?
  let untrackedList: CommitFileList?
  
  override init(selection: StashSelection)
  {
    self.untrackedSelection = selection.stash.untrackedCommit.map {
        CommitSelection(repository: selection.repository, commit: $0) }
    self.untrackedList = untrackedSelection.map { CommitFileList(selection: $0) }
    
    super.init(selection: selection)
  }
  
  func treeRoot(oldTree: NSTreeNode?) -> NSTreeNode
  {
    guard let mainList = self.mainList
    else { return NSTreeNode() }
    var mainRoot = mainList.treeRoot(oldTree: oldTree)
    
    if let untrackedList = self.untrackedList {
      let untrackedRoot = untrackedList.treeRoot(oldTree: oldTree)
    
      add(untrackedRoot, to: &mainRoot, status: .untracked)
    }
    return mainRoot
  }
  
  func diffForFile(_ path: String) -> PatchMaker.PatchResult?
  {
    return stash.unstagedDiffForFile(path)
  }
  
  func commit(for path: String) -> Commit?
  {
    if let untrackedCommit = stash.untrackedCommit,
       untrackedCommit.tree?.entry(path: path) != nil {
      return untrackedCommit
    }
    else {
      return stash.mainCommit
    }
  }
  
  func dataForFile(_ path: String) -> Data?
  {
    if let untrackedCommit = stash.untrackedCommit,
       let untrackedData = repository.contentsOfFile(path: path,
                                                     at: untrackedCommit) {
      return untrackedData
    }
    else {
      guard let commit = stash.mainCommit
      else { return nil }
      
      return repository.contentsOfFile(path: path, at: commit)
    }
  }
  
  func blame(for path: String) -> Blame?
  {
    guard let startCommit = commit(for: path)
    else { return nil }
    
    return repository.blame(for: path, from: startCommit.oid, to: nil)
  }

  func fileURL(_ path: String) -> URL? { return nil }
}

func == (a: StashSelection, b: StashSelection) -> Bool
{
  return a.stash.mainCommit?.oid.sha == b.stash.mainCommit?.oid.sha
}
