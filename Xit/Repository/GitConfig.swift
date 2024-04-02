import Foundation

public protocol Config: AnyObject
{
  associatedtype Entry: ConfigEntry

  subscript(index: String) -> Bool? { get set }
  subscript(index: String) -> String? { get set }
  subscript(index: String) -> Int? { get set }
  
  var entries: AnySequence<Entry> { get }
  
  func invalidate()
}

/// Only values returned/accepted by overloads of Config.subscript() should
/// conform to this protocol.
protocol ConfigValueType: Hashable, Sendable {}
extension Bool: ConfigValueType {}
extension String: ConfigValueType {}
extension Int: ConfigValueType {}

extension Config
{
  func value<T>(for key: String) -> T? where T: ConfigValueType
  { value(type: T.self, for: key) as? T }

  func value(type: Any.Type, for key: String) -> Any?
  {
    switch type {
      case is Bool.Type:
        return self[key] as Bool?
      case is String.Type:
        return self[key] as String?
      case is Int.Type:
        return self[key] as Int?
      default:
        assertionFailure("invalid config value type")
        return nil
    }
  }

  func set<T>(value: T, for key: String) where T: ConfigValueType
  { set(value: value, type: T.self, for: key) }

  func set(value: Any, type: Any.Type, for key: String)
  {
    switch type {
      case is Bool.Type:
        self[key] = value as? Bool
      case is String.Type:
        self[key] = value as? String
      case is Int.Type:
        self[key] = value as? Int
      default:
        assertionFailure("invalid config value type")
    }
  }
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
  { Int(stringValue) ?? 0 }
}

/// An in-memory `Config` that uses a dictionary.
class DictionaryConfig: Config
{
  struct Entry: ConfigEntry
  {
    let name: String
    let stringValue: String
  }

  var store: [String: Any] = [:]

  subscript(index: String) -> Bool?
  { get { store[index] as? Bool } set { store[index] = newValue } }
  subscript(index: String) -> String?
  { get { store[index] as? String } set { store[index] = newValue } }
  subscript(index: String) -> Int?
  { get { store[index] as? Int } set { store[index] = newValue } }

  var entries: AnySequence<Entry>
  {
    .init(store.map { Entry(name: $0.key,
                            stringValue: $0.value as? String ?? "") })
  }

  func invalidate() {}
}

extension Config
{
  func urlString(remote: String) -> String?
  {
    return self[remote]
  }
  
  var userName: String? { self["user.name"] }
  var userEmail: String? { self["user.email"] }
  
  var fetchPrune: Bool { self["fetch.prune"] ?? false }
  
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
    return UserDefaults.xit.bool(forKey: PreferenceKeys.fetchTags)
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

final class GitConfig: Config
{
  typealias Entry = GitConfigEntry

  let config: OpaquePointer
  var snapshot: OpaquePointer?
  
  /// The config actually being read: the cached snapshot, if any, or the
  /// data residing in the various config files.
  var operativeConfig: OpaquePointer { snapshot ?? config }
  
  init?(repository: OpaquePointer)
  {
    guard let config = try? OpaquePointer.from({
      git_repository_config(&$0, repository)
    })
    else { return nil }
    
    self.config = config
    loadSnapshot()
  }
  
  init?(config: OpaquePointer)
  {
    self.config = config
    loadSnapshot()
  }

  /// Adds an app-level config file for settings changed by Xit.
  ///
  /// Among other things, having a separate file guards against corrupting
  /// the user's config file in case there are bugs (like not preserving
  /// multiline values).
  private func addAppConfig() throws
  {
    guard let appSupport = FileManager.default
                                      .urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
    else { throw RepoError.unexpected }
    let configURL = appSupport.appendingPathComponent("xit.gitconfig")

    try configURL.withUnsafeFileSystemRepresentation {
      guard let path = $0
      else { throw RepoError.unexpected }
      let result = git_config_add_file_ondisk(config, path, GIT_CONFIG_LEVEL_APP,
                                              nil, 1)

      try RepoError.throwIfGitError(result)
    }
  }
  
  static var `default`: GitConfig?
  {
    guard let config = try? OpaquePointer.from({
      git_config_open_default(&$0)
    })
    else { return nil }
    
    let result = GitConfig(config: config)

    do {
      try result?.addAppConfig()
    }
    catch {
      return nil
    }
    return result
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
      defer {
        git_buf_free(&buffer)
      }
      
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
    
    func next() -> GitConfigEntry?
    {
      guard let iterator = self.iterator,
            let entry: UnsafeMutablePointer<git_config_entry> = try? .from({
              git_config_next(&$0, iterator)
            })
      else { return nil }
      
      self.iterator = iterator
      // Iterator owns the entry, so we shouldn't free it
      return GitConfigEntry(entry: entry.pointee, owner: false)
    }
  }
  
  var entries: AnySequence<Entry>
  { AnySequence<Entry> { EntryIterator(config: self.operativeConfig) } }
}

class GitConfigEntry: ConfigEntry
{
  let entry: git_config_entry
  let owner: Bool

  var name: String { String(cString: entry.name) }
  var stringValue: String { String(cString: entry.value) }
  
  init(entry: git_config_entry, owner: Bool = true)
  {
    self.entry = entry
    self.owner = owner
  }
  
  deinit
  {
    guard owner else { return }
    var mutableEntry = entry

    git_config_entry_free(&mutableEntry)
  }
}
