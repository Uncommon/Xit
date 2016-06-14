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
  var treeRoot: NSTreeNode? { get }
  /// Are there staged and unstaged changes?
  var hasUnstaged: Bool { get }
  /// Is this used to stage and commit files?
  var canCommit: Bool { get }
  /// Get the diff for the given file.
  /// @param path Repository-relative file path.
  /// @param staged Whether to show the staged or unstaged diff. Ignored for
  /// models that don't have unstaged files.
  func diffForFile(path: String, staged: Bool) -> XTDiffDelta?
  // Get the contents of the given file.
  /// @param path Repository-relative file path.
  /// @param staged Whether to show the staged or unstaged diff. Ignored for
  /// models that don't have unstaged files.
  func dataForFile(path: String, staged: Bool) -> NSData?
  /// The URL of the unstaged file, if any.
  func unstagedFileURL(path: String) -> NSURL?
}


/// Changes for a selected commit in the history
class XTCommitChanges: NSObject, XTFileChangesModel {
  var repository: XTRepository
  var sha: String
  var shaToSelect: String? { return self.sha }
  var hasUnstaged: Bool { return false }
  var canCommit: Bool { return false }
  var changes: [XTFileChange] {
    return self.repository.changesForRef(self.sha, parent: self.diffParent) ?? []
  }
  var treeRoot: NSTreeNode? { return nil }
  /// SHA of the parent commit to use for diffs
  var diffParent: String?
  
  init(repository: XTRepository, sha: String)
  {
    self.repository = repository
    self.sha = sha
    
    super.init()
  }
  
  func diffForFile(path: String, staged: Bool) -> XTDiffDelta? {
    return self.repository.diffForFile(
        path, commitSHA: self.sha, parentSHA: self.diffParent)
  }
  
  func dataForFile(path: String, staged: Bool) -> NSData? {
    return self.repository.contentsOfFile(path, atCommit: self.sha)
  }
  
  func unstagedFileURL(path: String) -> NSURL? { return nil }
}


/// Changes for a selected stash, merging workspace, index, and untracked
class XTStashChanges: NSObject, XTFileChangesModel {
  var repository: XTRepository
  var stash: XTStash
  var hasUnstaged: Bool { return true }
  var canCommit: Bool { return false }
  var shaToSelect: String? { return stash.mainCommit.parents[0].SHA }
  var changes: [XTFileChange] { return self.stash.changes() }
  var treeRoot: NSTreeNode? { return nil }
  
  init(repository: XTRepository, index: UInt)
  {
    self.repository = repository
    self.stash = XTStash(repo: repository, index: index)
    
    super.init()
  }
  
  func diffForFile(path: String, staged: Bool) -> XTDiffDelta? {
    if staged {
      return self.stash.stagedDiffForFile(path)
    }
    else {
      return self.stash.unstagedDiffForFile(path)
    }
  }
  
  func dataForFile(path: String, staged: Bool) -> NSData? {
    if staged {
      guard let indexCommit = self.stash.indexCommit
      else { return nil }
      
      return self.repository.contentsOfFile(path, atCommit: indexCommit.SHA)
    }
    else {
      if let untrackedCommit = self.stash.untrackedCommit,
         let untrackedData = self.repository.contentsOfFile(path, atCommit: untrackedCommit.SHA) {
        return untrackedData
      }
      return self.repository.contentsOfFile(
          path, atCommit: self.stash.mainCommit.SHA)
    }
  }

  // Unstaged files are stored in commits, so there is no URL.
  func unstagedFileURL(path: String) -> NSURL? { return nil }
}


/// Staged and unstaged workspace changes
class XTStagingChanges: NSObject, XTFileChangesModel {
  var repository: XTRepository
  var shaToSelect: String? { return XTStagingSHA }
  var hasUnstaged: Bool { return true }
  var canCommit: Bool { return true }
  var changes: [XTFileChange]
    { return repository.changesForRef(XTStagingSHA, parent: nil) ?? [] }
  var treeRoot: NSTreeNode? { return nil }
  
  init(repository: XTRepository)
  {
    self.repository = repository
    
    super.init()
  }
  
  func diffForFile(path: String, staged: Bool) -> XTDiffDelta? {
    if staged {
      return self.repository.stagedDiffForFile(path)
    }
    else {
      return self.repository.unstagedDiffForFile(path)
    }
  }
  
  func dataForFile(path: String, staged: Bool) -> NSData? {
    if staged {
      return self.repository.contentsOfStagedFile(path)
    }
    else {
      let url = self.repository.repoURL.URLByAppendingPathComponent(path)
      
      return NSData(contentsOfURL: url)
    }
  }
  
  func unstagedFileURL(path: String) -> NSURL? {
    return self.repository.repoURL.URLByAppendingPathComponent(path)
  }
}
