import Foundation
import AppKit

/// Changes for a selected stash, merging workspace, index, and untracked
final class StashSelection: StagedUnstagedSelection
{
  unowned var repository: any FileChangesRepo
  let stash: any Stash
  var canCommit: Bool { false }
  var oidToSelect: (any OID)? { stash.anyMainCommit?.parentOIDs.first }
  var fileList: any FileListModel { stagedList }
  var unstagedFileList: any FileListModel { unstagedList }
  var amending: Bool { false }
  
  // Initialization requires a reference to self
  private(set) var stagedList: StashStagedList! = nil
  private(set) var unstagedList: StashUnstagedList! = nil
  
  convenience init(repository: any FileChangesRepo & Stashing, index: UInt)
  {
    self.init(repository: repository,
              stash: repository.stash(index: index, message: nil))
  }
  
  init(repository: any FileChangesRepo, stash: any Stash)
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
  unowned let repository: any FileChangesRepo

  let mainSelection: CommitSelection?
  let mainList: CommitFileList?
  let stash: any Stash
  
  init(selection: StashSelection)
  {
    self.repository = selection.repository
    self.stash = selection.stash
    if let mainCommit = selection.stash.anyMainCommit {
      self.mainSelection = CommitSelection(repository: selection.repository,
                                           commit: mainCommit)
      self.mainList = CommitFileList(repository: selection.repository,
                                     commit: mainCommit)
    }
    else {
      self.mainSelection = nil
      self.mainList = nil
    }
  }

  func equals(_ other: any FileListModel) -> Bool
  {
    guard let other = other as? StashFileList
    else { return false }
    guard let mainCommit = stash.anyMainCommit,
          let otherCommit = other.stash.anyMainCommit
    else {
      assertionFailure("main commit should not be missing")
      return false
    }
    return mainCommit.id.equals(otherCommit.id)
  }
}

/// File list for the staged portion of a stash
class StashStagedList: StashFileList, FileListModel
{
  let indexSelection: CommitSelection?
  let indexList: CommitFileList?
  
  var changes: [FileChange]
  {
    stash.anyIndexCommit.map {
      repository.changes(for: $0.id, parent: nil)
    } ?? []
  }

  override init(selection: StashSelection)
  {
    self.indexSelection = selection.stash.anyIndexCommit.map {
        CommitSelection(repository: selection.repository, commit: $0) }
    self.indexList = indexSelection.map {
        CommitFileList(repository: $0.repository, commit: $0.commit) }

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
    guard let indexCommit = stash.anyIndexCommit
    else { return nil }
    
    return repository.contentsOfFile(path: path, at: indexCommit)
  }

  func blame(for path: String) -> (any Blame)?
  {
    guard let indexCommit = stash.anyIndexCommit
    else { return nil }
    
    return repository.blame(for: path, from: indexCommit.id, to: nil)
  }

  func fileURL(_ path: String) -> URL?
  {
    return nil
  }
}

/// File list for the unstaged portion of a stash
final class StashUnstagedList: StashFileList, FileListModel
{
  var changes: [FileChange] { stash.workspaceChanges() }
  
  let untrackedSelection: CommitSelection?
  let untrackedList: CommitFileList?
  
  override init(selection: StashSelection)
  {
    self.untrackedSelection = selection.stash.anyUntrackedCommit.map {
        CommitSelection(repository: selection.repository, commit: $0) }
    self.untrackedList = untrackedSelection.map {
        CommitFileList(repository: $0.repository, commit: $0.commit) }
    
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
  
  func commit(for path: String) -> (any Commit)?
  {
    if let untrackedCommit = stash.anyUntrackedCommit,
       untrackedCommit.anyTree?.anyEntry(path: path) != nil {
      return untrackedCommit
    }
    else {
      return stash.anyMainCommit
    }
  }
  
  func dataForFile(_ path: String) -> Data?
  {
    if let untrackedCommit = stash.anyUntrackedCommit,
       let untrackedData = repository.contentsOfFile(path: path,
                                                     at: untrackedCommit) {
      return untrackedData
    }
    else {
      guard let commit = stash.anyMainCommit
      else { return nil }
      
      return repository.contentsOfFile(path: path, at: commit)
    }
  }
  
  func blame(for path: String) -> (any Blame)?
  {
    guard let startCommit = commit(for: path)
    else { return nil }
    
    return repository.blame(for: path, from: startCommit.id, to: nil)
  }

  func fileURL(_ path: String) -> URL? { return nil }
}
