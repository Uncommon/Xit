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
