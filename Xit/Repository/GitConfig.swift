import Foundation

public protocol Config: AnyObject
{
  subscript(index: String) -> Bool? { get set }
  subscript(index: String) -> String? { get set }
  subscript(index: String) -> Int? { get set }
}

extension Config
{
  func urlString(remote: String) -> String?
  {
    return self[remote]
  }
  
  var userName: String? { return self["user.name"] }
  var userEmail: String? { return self["user.email"] }
  
  var fetchPrune: Bool { return self["fetch.prune"] ?? false }
  
  /// Returns the prune setting for `remote`, or falls back to the general
  /// `fetch.prune` setting.
  func fetchPrune(remote: String) -> Bool
  {
    if self["remote.\(remote).prune"] ?? false {
      return true
    }
    return fetchPrune
  }
  
  /// Returns true if `--no-tags` is set for `remote.<remote>.tagOpt`.
  func fetchTags(remote: String) -> Bool
  {
    if self["remote.\(remote).tagOpt"] == "--no-tags" {
      return false
    }
    return UserDefaults.standard.bool(
      forKey: GitPrefsController.PrefKey.fetchTags)
  }
  
  func commitTemplate() -> String?
  {
    return self["commit.template"]
  }
  
  func branchRemote(_ branch: String) -> String?
  {
    return self["branch.\(branch).remote"]
  }
  
  func branchMerge(_ branch: String) -> String?
  {
    return self["branch.\(branch).merge"]
  }
  
  func remoteURL(_ remote: String) -> String?
  {
    return self["remote.\(remote).url"]
  }
  
  func remoteFetch(_ remote: String) -> String?
  {
    return self["remote.\(remote).fetch"]
  }
  
  func remotePushURL(_ remote: String) -> String?
  {
    return self["remote.\(remote).pushurl"]
  }
}

class GitConfig: Config
{
  let config: OpaquePointer
  var snapshot: OpaquePointer?
  
  var readConfig: OpaquePointer { return snapshot ?? config }
  
  func loadSnapshot()
  {
    var snapshot: OpaquePointer?
    let result = git_config_snapshot(&snapshot, config)
    guard result == 0
    else {
      snapshot = nil
      return
    }
    
    self.snapshot = snapshot
  }
  
  init?(repository: OpaquePointer)
  {
    let config = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let result = git_repository_config(config, repository)
    guard result == 0,
          let finalConfig = config.pointee
    else { return nil }
    
    self.config = finalConfig
    loadSnapshot()
  }
  
  init(config: OpaquePointer)
  {
    self.config = config
    loadSnapshot()
  }
  
  static var `default`: GitConfig?
  {
    let config = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let result = git_config_open_default(config)
    guard result == 0,
          let finalConfig = config.pointee
    else { return nil }
    
    return GitConfig(config: finalConfig)
  }
  
  deinit
  {
    git_config_free(config)
    if let snapshot = self.snapshot {
      git_config_free(snapshot)
    }
  }
  
  subscript(index: String) -> Bool?
  {
    get
    {
      let b = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
      let result = git_config_get_bool(b, readConfig, index)
      guard result == 0
      else { return nil }
      
      return b.pointee != 0
    }
    set
    {
      if let value = newValue {
        git_config_set_bool(readConfig, index, value ? 1 : 0)
      }
      else {
        git_config_delete_entry(readConfig, index)
      }
      loadSnapshot()
    }
  }
  
  subscript(index: String) -> String?
  {
    get
    {
      let buffer = UnsafeMutablePointer<git_buf>.allocate(capacity: 1)
      
      buffer.pointee.ptr = nil
      buffer.pointee.asize = 0
      buffer.pointee.size = 0
      
      let result = git_config_get_string_buf(buffer, config, index)
      guard result == 0
      else { return nil }
      
      return String(cString: buffer.pointee.ptr)
    }
    set
    {
      if let value = newValue {
        git_config_set_string(config, index, value)
      }
      else {
        git_config_delete_entry(config, index)
      }
      loadSnapshot()
    }
  }
  
  subscript(index: String) -> Int?
  {
    get
    {
      let b = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
      let result = git_config_get_int32(b, config, index)
      guard result == 0
      else { return nil }
      
      return Int(b.pointee)
    }
    set
    {
      if let value = newValue {
        git_config_set_int32(config, index, Int32(value))
      }
      else {
        git_config_delete_entry(config, index)
      }
      loadSnapshot()
    }
  }
}
