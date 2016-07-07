import Cocoa

/// Provides access to repository config options. This class is an exception to
/// the rule that direct Objective Git usage should be avoided outside of
/// `XTRepository`.
class XTConfig: NSObject {
  
  let config: GTConfiguration?
  
  init(repository: XTRepository)
  {
    self.config = try? repository.gtRepo.configuration()
    if config == nil {
      NSLog("Could not get config")
    }
  }
  
  /// Returns the `fetch.prune` setting.
  final func fetchPrune() -> Bool
  {
    guard let config = config else { return false }
    return config.boolForKey("fetch.prune")
  }
  
  /// Returns the prune setting for `remote`, or falls back to the general
  /// `fetch.prune` setting.
  final func fetchPrune(remote: String) -> Bool
  {
    guard let config = config else { return false }
    if config.boolForKey("remote.\(remote).prune") {
      return true
    }
    return fetchPrune()
  }
  
  /// Returns true if `--no-tags` is set for `remote.<remote>.tagOpt`.
  final func fetchTags(remote: String) -> Bool
  {
    guard let config = config else { return true }
    if config.stringForKey("remote.\(remote).tagOpt") == "--no-tags" {
      return false
    }
    return true
  }
}
