import Cocoa
import ObjectiveGit

public protocol Submodule
{
  var name: String { get }
  var path: String { get }
  var url: URL? { get }
  
  var ignoreRule: SubmoduleIgnore { get set }
  var updateStrategy: SubmoduleUpdate { get set }
  var recurse: SubmoduleRecurse { get set }
}

struct SubmoduleStatus: OptionSet
{
  let rawValue: git_submodule_status_t.RawValue
  
  init(_ status: git_submodule_status_t)
  {
    self.rawValue = status.rawValue
  }
  
  init(rawValue: UInt32)
  {
    self.rawValue = rawValue
  }
  
  static let inHead = SubmoduleStatus(GIT_SUBMODULE_STATUS_IN_HEAD)
  static let inIndex = SubmoduleStatus(GIT_SUBMODULE_STATUS_IN_INDEX)
  static let inConfig = SubmoduleStatus(GIT_SUBMODULE_STATUS_IN_CONFIG)
  static let inWorkDir = SubmoduleStatus(GIT_SUBMODULE_STATUS_IN_WD)

  static let indexAdded = SubmoduleStatus(GIT_SUBMODULE_STATUS_INDEX_ADDED)
  static let indexDeleted = SubmoduleStatus(GIT_SUBMODULE_STATUS_INDEX_DELETED)
  static let indexModified = SubmoduleStatus(GIT_SUBMODULE_STATUS_INDEX_MODIFIED)

  static let wdUninitialized =
      SubmoduleStatus(GIT_SUBMODULE_STATUS_WD_UNINITIALIZED)
  static let wdAdded = SubmoduleStatus(GIT_SUBMODULE_STATUS_WD_ADDED)
  static let wdDeleted = SubmoduleStatus(GIT_SUBMODULE_STATUS_WD_DELETED)
  static let wdModified = SubmoduleStatus(GIT_SUBMODULE_STATUS_WD_MODIFIED)
  static let wdIndexModified =
      SubmoduleStatus(GIT_SUBMODULE_STATUS_WD_INDEX_MODIFIED)
  static let wdWDModified = SubmoduleStatus(GIT_SUBMODULE_STATUS_WD_WD_MODIFIED)
  static let wdUntracked = SubmoduleStatus(GIT_SUBMODULE_STATUS_WD_UNTRACKED)
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
  
  public var name: String { return String(cString: git_submodule_name(submodule)) }
  public var path: String { return String(cString: git_submodule_path(submodule)) }
  public var url: URL?
  {
    return URL(string: String(cString: git_submodule_url(submodule)))
  }
  
  public var ignoreRule: SubmoduleIgnore
  {
    get
    {
      return SubmoduleIgnore(ignore: git_submodule_ignore(submodule))
    }
    set
    {
      git_submodule_set_ignore(git_submodule_owner(submodule), name,
                               git_submodule_ignore_t(newValue.rawValue))
    }
  }
  
  public var updateStrategy: SubmoduleUpdate
  {
    get
    {
      return SubmoduleUpdate(update: git_submodule_update_strategy(submodule))
    }
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
      return SubmoduleRecurse(recurse:
          git_submodule_fetch_recurse_submodules(submodule))
    }
    set
    {
      git_submodule_set_fetch_recurse_submodules(
            git_submodule_owner(submodule), name,
            git_submodule_recurse_t(newValue.rawValue))
    }
  }
}
