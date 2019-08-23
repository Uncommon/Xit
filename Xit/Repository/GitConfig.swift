import Foundation

public protocol Config: AnyObject
{
  subscript(index: String) -> Bool? { get set }
  subscript(index: String) -> String? { get set }
  subscript(index: String) -> Int? { get set }
  
  var entries: AnySequence<ConfigEntry> { get }
  
  func invalidate()
}

public protocol ConfigEntry
{
  var name: String { get }
  var stringValue: String { get }
}

extension ConfigEntry
{
  var boolValue: Bool
  {
    // Replicates the logic of git_config_parse_bool
    switch stringValue.lowercased() {
      case "true", "yes", "on":
        return true
      default:
        return intValue != 0
    }
  }
  
  var intValue: Int
  {
    return Int(stringValue) ?? 0
  }
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
        forKey: GeneralPrefsConroller.PrefKey.fetchTags)
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
  
  /// The config actually being read: the cached snapshot, if any, or the
  /// data residing in the various config files.
  var operativeConfig: OpaquePointer { return snapshot ?? config }
  
  init?(repository: OpaquePointer)
  {
    var config: OpaquePointer? = nil
    let result = git_repository_config(&config, repository)
    guard result == 0,
          let finalConfig = config
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
    var config: OpaquePointer? = nil
    let result = git_config_open_default(&config)
    guard result == 0,
          let finalConfig = config
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
      var b: Int32 = 0
      let result = git_config_get_bool(&b, operativeConfig, index)
      guard result == 0
      else { return nil }
      
      return b != 0
    }
    set
    {
      if let value = newValue {
        git_config_set_bool(config, index, value ? 1 : 0)
      }
      else {
        git_config_delete_entry(config, index)
      }
      loadSnapshot()
    }
  }
  
  subscript(index: String) -> String?
  {
    get
    {
      var buffer = git_buf()
      let result = git_config_get_string_buf(&buffer, operativeConfig, index)
      guard result == 0
      else { return nil }
      
      return String(cString: buffer.ptr)
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
      var b: Int32 = 0
      let result = git_config_get_int32(&b, operativeConfig, index)
      guard result == 0
      else { return nil }
      
      return Int(b)
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
  
  func invalidate()
  {
    loadSnapshot()
  }
  
  class EntryIterator: IteratorProtocol
  {
    private var iterator: UnsafeMutablePointer<git_config_iterator>?
    
    init(config: OpaquePointer)
    {
      self.iterator = .allocate(capacity: 1)
      
      let result = git_config_iterator_new(&iterator, config)
      guard result == 0
      else {
        self.iterator = nil
        return
      }
    }
    
    deinit
    {
      if let iterator = self.iterator {
        git_config_iterator_free(iterator)
      }
    }
    
    func next() -> ConfigEntry?
    {
      guard let iterator = self.iterator
      else { return nil }
      var entry: UnsafeMutablePointer<git_config_entry>?
      let result = git_config_next(&entry, iterator)
      guard result == 0,
            let finalEntry = entry?.pointee
      else { return nil }
      
      self.iterator = iterator
      return GitConfigEntry(entry: finalEntry)
    }
  }
  
  var entries: AnySequence<ConfigEntry>
  {
    return AnySequence<ConfigEntry> { EntryIterator(config: self.operativeConfig) }
  }
}

class GitConfigEntry: ConfigEntry
{
  let entry: git_config_entry
  
  var name: String { return String(cString: entry.name) }
  var stringValue: String { return String(cString: entry.value) }
  
  init(entry: git_config_entry)
  {
    self.entry = entry
  }
  
  deinit
  {
    if let free = entry.free {
      var mutableEntry = entry
      
      free(&mutableEntry)
    }
  }
}
