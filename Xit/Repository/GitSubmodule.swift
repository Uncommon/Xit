import Foundation

public protocol Submodule
{
  var name: String { get }
  var path: String { get }
  var url: URL? { get }
  
  var ignoreRule: SubmoduleIgnore { get set }
  var updateStrategy: SubmoduleUpdate { get set }
  var recurse: SubmoduleRecurse { get set }
  
  func update(initialize: Bool, callbacks: RemoteCallbacks) throws
}

extension Submodule
{
  public func update(callbacks: RemoteCallbacks) throws
  {
    try update(initialize: true, callbacks: callbacks)
  }
}

public struct SubmoduleStatus: OptionSet
{
  public let rawValue: git_submodule_status_t.RawValue
  
  init(_ status: git_submodule_status_t)
  {
    self.rawValue = status.rawValue
  }
  
  public init(rawValue: UInt32)
  {
    self.rawValue = rawValue
  }
  
  static let inHead = Self(GIT_SUBMODULE_STATUS_IN_HEAD)
  static let inIndex = Self(GIT_SUBMODULE_STATUS_IN_INDEX)
  static let inConfig = Self(GIT_SUBMODULE_STATUS_IN_CONFIG)
  static let inWorkDir = Self(GIT_SUBMODULE_STATUS_IN_WD)

  static let indexAdded = Self(GIT_SUBMODULE_STATUS_INDEX_ADDED)
  static let indexDeleted = Self(GIT_SUBMODULE_STATUS_INDEX_DELETED)
  static let indexModified = Self(GIT_SUBMODULE_STATUS_INDEX_MODIFIED)

  static let wdUninitialized = Self(GIT_SUBMODULE_STATUS_WD_UNINITIALIZED)
  static let wdAdded = Self(GIT_SUBMODULE_STATUS_WD_ADDED)
  static let wdDeleted = Self(GIT_SUBMODULE_STATUS_WD_DELETED)
  static let wdModified = Self(GIT_SUBMODULE_STATUS_WD_MODIFIED)
  static let wdIndexModified = Self(GIT_SUBMODULE_STATUS_WD_INDEX_MODIFIED)
  static let wdWDModified = Self(GIT_SUBMODULE_STATUS_WD_WD_MODIFIED)
  static let wdUntracked = Self(GIT_SUBMODULE_STATUS_WD_UNTRACKED)
}

extension SubmoduleIgnore
{
  init(ignore: git_submodule_ignore_t)
  {
    self = SubmoduleIgnore(rawValue: ignore.rawValue) ?? .unspecified
  }
}

extension SubmoduleUpdate
{
  init(update: git_submodule_update_t)
  {
    self = SubmoduleUpdate(rawValue: update.rawValue) ?? .default
  }
}

extension SubmoduleRecurse
{
  init(recurse: git_submodule_recurse_t)
  {
    self = SubmoduleRecurse(rawValue: recurse.rawValue) ?? .no
  }
}

public class GitSubmodule: Submodule
{
  var submodule: OpaquePointer
  
  init(submodule: OpaquePointer)
  {
    self.submodule = submodule
  }
  
  public var name: String { .init(cString: git_submodule_name(submodule)) }
  public var path: String { .init(cString: git_submodule_path(submodule)) }
  public var url: URL?
  { URL(string: String(cString: git_submodule_url(submodule))) }
  
  public var owner: OpaquePointer { git_submodule_owner(submodule) }
  
  public var status: SubmoduleStatus
  {
    var gitStatus: UInt32 = 0
    let result = git_submodule_status(&gitStatus, owner, name,
                                      GIT_SUBMODULE_IGNORE_NONE)
    
    try? RepoError.throwIfGitError(result)
    return SubmoduleStatus(rawValue: gitStatus)
  }
  
  public var ignoreRule: SubmoduleIgnore
  {
    get
    { SubmoduleIgnore(ignore: git_submodule_ignore(submodule)) }
    set
    {
      git_submodule_set_ignore(git_submodule_owner(submodule), name,
                               git_submodule_ignore_t(newValue.rawValue))
    }
  }
  
  public var updateStrategy: SubmoduleUpdate
  {
    get
    { SubmoduleUpdate(update: git_submodule_update_strategy(submodule)) }
    set
    {
      git_submodule_set_update(git_submodule_owner(submodule), name,
                               git_submodule_update_t(newValue.rawValue))
    }
  }
  
  public var recurse: SubmoduleRecurse
  {
    get
    {
      SubmoduleRecurse(recurse:
          git_submodule_fetch_recurse_submodules(submodule))
    }
    set
    {
      git_submodule_set_fetch_recurse_submodules(
            git_submodule_owner(submodule), name,
            git_submodule_recurse_t(newValue.rawValue))
    }
  }
  
  /// Starts adding a new submodule. After this, clone the submodule, and then
  /// call `addFinalize()`.
  static func add(to repo: OpaquePointer, url: String, path: String) throws -> GitSubmodule
  {
    let submodule = try OpaquePointer.from {
      git_submodule_add_setup(&$0, repo, url, path, 0)
    }
    
    return GitSubmodule(submodule: submodule)
  }
  
  public func addFinalize() throws
  {
    try RepoError.throwIfGitError(git_submodule_add_finalize(submodule))
  }
  
  public func update(initialize: Bool, callbacks: RemoteCallbacks) throws
  {
    var options = git_submodule_update_options.defaultOptions()
    
    try git_remote_callbacks.withCallbacks(callbacks) {
      (gitCallbacks) in
      let result = git_submodule_update(submodule, initialize ? 1 : 0, &options)
      
      try RepoError.throwIfGitError(result)
    }
  }
  
  public func addToIndex(writeImmediately: Bool = true) throws
  {
    let result = git_submodule_add_to_index(submodule, writeImmediately ? 1 : 0)
    
    try RepoError.throwIfGitError(result)
  }
  
  public func reload(force: Bool = true) throws
  {
    let result = git_submodule_reload(submodule, force ? 1 : 0)
    
    try RepoError.throwIfGitError(result)
  }
}
