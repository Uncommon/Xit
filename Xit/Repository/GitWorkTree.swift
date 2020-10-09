import Foundation

public enum WorkTreeLockStatus
{
  case unlocked
  case locked(reason: String)
  case error(Int32)
}

public struct WorkTreePruneOptions: OptionSet
{
  public let rawValue: UInt32
  
  public static let valid = Self(GIT_WORKTREE_PRUNE_VALID)
  public static let locked = Self(GIT_WORKTREE_PRUNE_LOCKED)
  public static let workingTree = Self(GIT_WORKTREE_PRUNE_WORKING_TREE)

  public init(rawValue: UInt32) { self.rawValue = rawValue }
  init(_ flag: git_worktree_prune_t) { self.rawValue = flag.rawValue }
}

public protocol WorkTree
{
  var name: String { get }
  var path: String { get }
  var lockStatus: WorkTreeLockStatus { get }
  
  func validate() throws
  
  func lock(reason: String) throws
  func unlock() throws
  
  func isPrunable(options: WorkTreePruneOptions) -> Bool
  func prune(options: WorkTreePruneOptions) throws
}

class GitWorkTree: WorkTree
{
  let workTree: OpaquePointer
  
  var name: String
  { String(cString: git_worktree_name(workTree)) }
  
  var path: String
  { String(cString: git_worktree_path(workTree)) }
  
  var lockStatus: WorkTreeLockStatus
  {
    let reasonBuffer = UnsafeMutablePointer<git_buf>.allocate(capacity: 1)
    
    switch git_worktree_is_locked(reasonBuffer, workTree) {
      case 0:
        return .unlocked
      case let error where error < 0:
        return .error(error)
      case 1...:
        return .locked(reason: String(gitBuffer: reasonBuffer.pointee) ?? "")
      default:
        fatalError("this should be unreachable")
    }
  }
  
  init?(name: String, repository: OpaquePointer)
  {
    guard let workTree = try? OpaquePointer.from({
      git_worktree_lookup(&$0, repository, name) })
    else { return nil }
    
    self.workTree = workTree
  }
  
  init?(repository: OpaquePointer)
  {
    guard let workTree = try? OpaquePointer.from({
      git_worktree_open_from_repository(&$0, repository) })
    else { return nil }
    
    self.workTree = workTree
  }
  
  deinit
  {
    git_worktree_free(workTree)
  }
  
  func validate() throws
  {
    try RepoError.throwIfGitError(git_worktree_validate(workTree))
  }
  
  func lock(reason: String) throws
  {
    try RepoError.throwIfGitError(git_worktree_lock(workTree, reason))
  }
  
  func unlock() throws
  {
    try RepoError.throwIfGitError(git_worktree_unlock(workTree))
  }
  
  func isPrunable(options: WorkTreePruneOptions) -> Bool
  {
    var gitOptions = git_worktree_prune_options(options)
    
    return git_worktree_is_prunable(workTree, &gitOptions) > 0
  }
  
  func prune(options: WorkTreePruneOptions) throws
  {
    var gitOptions = git_worktree_prune_options(options)
    
    try RepoError.throwIfGitError(git_worktree_prune(workTree, &gitOptions))
  }
}

extension git_worktree_prune_options
{
  init(_ options: WorkTreePruneOptions)
  {
    self.init(version: UInt32(GIT_WORKTREE_PRUNE_OPTIONS_VERSION),
              flags: options.rawValue)
  }
}
