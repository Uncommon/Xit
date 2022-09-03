import Cocoa


typealias FileChangesRepo =
    BasicRepository & CommitReferencing & FileDiffing & FileContents &
    FileStaging & FileStatusDetection

/// Protocol for a commit or commit-like object, with metadata, files, and diffs.
protocol RepositorySelection: AnyObject
{
  var repository: any FileChangesRepo { get set }
  /// SHA for commit to be selected in the history list
  var oidToSelect: (any OID)? { get }
  /// Is this used to stage and commit files? Differentiates between staging
  /// and stash changes, which both have unstaged lists.
  var canCommit: Bool { get }
  /// The primary or staged file list.
  var fileList: any FileListModel { get }
}

/// A selection that also has an unstaged file list
protocol StagedUnstagedSelection: RepositorySelection
{
  /// The unstaged file list
  var unstagedFileList: any FileListModel { get }
  var amending: Bool { get }
}

extension StagedUnstagedSelection
{
  func counts() -> (staged: Int, unstaged: Int)
  {
    let indexChanges = fileList.changes
    let workspaceChanges = unstagedFileList.changes
    let unmodifiedCounter: (FileChange) -> Bool = { $0.status != .unmodified }
    let stagedCount = indexChanges.count(where: unmodifiedCounter)
    let unstagedCount = workspaceChanges.count(where: unmodifiedCounter)
    
    return (stagedCount, unstagedCount)
  }
}

extension RepositorySelection
{
  func list(staged: Bool) -> any FileListModel
  {
    return staged ? fileList :
        (self as? StagedUnstagedSelection)?.unstagedFileList ?? fileList
  }

  func equals(_ other: (any RepositorySelection)?) -> Bool
  {
    guard let other = other
    else {
      return false
    }

    return type(of: self) == type(of: other) &&
           oidToSelect == other.oidToSelect
  }
}

enum StagingType
{
  // No staging actions
  case none
  // Index: can unstage
  case index
  // Workspace: can stage
  case workspace
}

func == (a: (any RepositorySelection)?, b: (any RepositorySelection)?) -> Bool
{
  return a?.equals(b) ?? (b == nil)
}

func != (a: (any RepositorySelection)?, b: (any RepositorySelection)?) -> Bool
{
  return !(a == b)
}
