import Foundation

/// Changes for a selected stash, merging workspace, index, and untracked
class StashChanges: FileChangesModel
{
  unowned var repository: FileChangesRepo
  var stash: Stash
  var hasUnstaged: Bool { return true }
  var canCommit: Bool { return false }
  var shaToSelect: String? { return stash.mainCommit?.parentSHAs[0] }
  var changes: [FileChange] { return stash.changes() }
  
  init(repository: FileChangesRepo & Stashing, index: UInt)
  {
    self.repository = repository
    self.stash = repository.stash(index: index, message: nil)
  }
  
  init(repository: FileChangesRepo, stash: XTStash)
  {
    self.repository = repository
    self.stash = stash
  }
  
  func treeRoot(oldTree: NSTreeNode?) -> NSTreeNode
  {
    guard let mainModel = stash.mainCommit.map({
        CommitChanges(repository: repository, commit: $0) })
    else { return NSTreeNode() }
    var mainRoot = mainModel.treeRoot(oldTree: oldTree)
    
    if let indexCommit = stash.indexCommit {
      let indexModel = CommitChanges(repository: repository,
                                     commit: indexCommit)
      let indexRoot = indexModel.treeRoot(oldTree: oldTree)
      
      combineTrees(unstagedTree: &mainRoot,
                   stagedTree: indexRoot)
    }
    if let untrackedCommit = stash.untrackedCommit {
      let untrackedModel = CommitChanges(repository: repository,
                                         commit: untrackedCommit)
      let untrackedRoot = untrackedModel.treeRoot(oldTree: oldTree)
    
      add(untrackedRoot, to: &mainRoot)
    }
    return mainRoot
  }
  
  func diffForFile(_ path: String, staged: Bool) -> PatchMaker.PatchResult?
  {
    if staged {
      return stash.stagedDiffForFile(path)
    }
    else {
      return stash.unstagedDiffForFile(path)
    }
  }
  
  func commit(for path: String, staged: Bool) -> Commit?
  {
    if staged {
      return stash.indexCommit
    }
    else {
      if let untrackedCommit = stash.untrackedCommit as? XTCommit,
         untrackedCommit.tree?.entry(path: path) != nil {
        return untrackedCommit
      }
      else {
        return stash.mainCommit
      }
    }
  }
  
  func blame(for path: String, staged: Bool) -> Blame?
  {
    guard let startCommit = commit(for: path, staged: staged)
    else { return nil }
    
    return repository.blame(for: path, from: startCommit.oid, to: nil)
  }
  
  func dataForFile(_ path: String, staged: Bool) -> Data?
  {
    if staged {
      guard let indexCommit = stash.indexCommit
      else { return nil }
      
      return repository.contentsOfFile(path: path, at: indexCommit)
    }
    else {
      if let untrackedCommit = stash.untrackedCommit,
         let untrackedData = repository.contentsOfFile(
              path: path, at: untrackedCommit) {
        return untrackedData
      }
      
      guard let commit = stash.mainCommit
      else { return nil }
      
      return repository.contentsOfFile(path: path, at: commit)
    }
  }

  // Unstaged files are stored in commits, so there is no URL.
  func unstagedFileURL(_ path: String) -> URL? { return nil }
}

func == (a: StashChanges, b: StashChanges) -> Bool
{
  return a.stash.mainCommit?.oid.sha == b.stash.mainCommit?.oid.sha
}
