import Cocoa

/// Provides convenience functions for repository config options.
class XTConfig: NSObject
{
  let config: Config?
  
  init(config: Config?)
  {
    self.config = config
    
    super.init()
  }
  
  final func urlString(forRemote remote: String) -> String?
  {
    return config?[remote]
  }
  
  /// Returns the `user.name` setting.
  final func userName() -> String?
  {
    return config?["user.name"]
  }
  
  /// Returns the `user.email` setting.
  final func userEmail() -> String?
  {
    return config?["user.email"]
  }

  /// Returns the `fetch.prune` setting.
  final func fetchPrune() -> Bool
  {
    return config?["fetch.prune"] ?? false
  }
  
  /// Returns the prune setting for `remote`, or falls back to the general
  /// `fetch.prune` setting.
  final func fetchPrune(_ remote: String) -> Bool
  {
    if config?["remote.\(remote).prune"] ?? false {
      return true
    }
    return fetchPrune()
  }
  
  /// Returns true if `--no-tags` is set for `remote.<remote>.tagOpt`.
  final func fetchTags(_ remote: String) -> Bool
  {
    if config?["remote.\(remote).tagOpt"] == "--no-tags" {
      return false
    }
    return UserDefaults.standard.bool(
        forKey: XTGitPrefsController.PrefKey.fetchTags)
  }
  
  final func commitTemplate() -> String?
  {
    return config?["commit.template"]
  }
}
