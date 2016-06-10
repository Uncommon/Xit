import Cocoa

/**
 * Protocol for a commit or commit-like object,
 * with metadata, files, and diffs.
 */
@objc protocol XTFileChangesModel {
  var repository: XTRepository { get set }
  /// SHA for commit to be selected in the history list
  var shaToSelect: String? { get }
  /// Changes displayed in the file list
  var changes: [XTFileChange] { get }
  /// Top level of the file tree
  var treeRoot: [XTFileChange] { get }
  /// Are there staged and unstaged changes?
  var hasUnstaged: Bool { get }
}


/// Changes for a selected commit in the history
class XTCommitChanges: NSObject, XTFileChangesModel {
  var repository: XTRepository
  var sha: String
  var shaToSelect: String? { return self.sha }
  var hasUnstaged: Bool { return false }
  var changes: [XTFileChange] {
    return self.repository.changesForRef(self.sha, parent: self.diffParent) ?? []
  }
  var treeRoot: [XTFileChange] { return [] }
  /// SHA of the parent commit to use for diffs
  var diffParent: String?
  
  init(repository: XTRepository, sha: String)
  {
    self.repository = repository
    self.sha = sha
    
    super.init()
  }
}


/// Changes for a selected stash, merging workspace, index, and untracked
class XTStashChanges: NSObject, XTFileChangesModel {
  var repository: XTRepository
  var stash: XTStash
  var hasUnstaged: Bool { return true; }
  var shaToSelect: String? { return stash.mainCommit.parents[0].SHA }
  var changes: [XTFileChange] { return self.stash.changes() }
  var treeRoot: [XTFileChange] { return [] }
  
  init(repository: XTRepository, index: UInt)
  {
    self.repository = repository
    self.stash = XTStash(repo: repository, index: index)
    
    super.init()
  }
}


/// Staged and unstaged workspace changes
class XTStagingChanges: NSObject, XTFileChangesModel {
  var repository: XTRepository
  var shaToSelect: String? { return XTStagingSHA }
  var hasUnstaged: Bool { return true; }
  var changes: [XTFileChange]
    { return repository.changesForRef(XTStagingSHA, parent: nil) ?? [] }
  var treeRoot: [XTFileChange] { return [] }
  
  init(repository: XTRepository)
  {
    self.repository = repository
    
    super.init()
  }
}
