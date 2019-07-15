import Foundation


protocol OptionBits
{
  func test(_ flag: Self) -> Bool
}

extension OptionBits where Self: RawRepresentable, RawValue: BinaryInteger
{
  func test(_ flag: Self) -> Bool
  {
    return (rawValue & flag.rawValue) != 0
  }
}

extension git_status_t: OptionBits {}
extension git_credtype_t: OptionBits {}

protocol GitVersionedOptions
{
  typealias Initializer = (UnsafeMutablePointer<Self>?, UInt32) -> Int32
  
  static var version: Int32 { get }
  static var initializer: Initializer { get }

  init()
}

extension GitVersionedOptions
{
  mutating func initializeWithVersion()
  {
    _ = Self.initializer(&self, UInt32(Self.version))
  }
  
  static func defaultOptions() -> Self
  {
    var options = Self()
    
    options.initializeWithVersion()
    return options
  }
}

extension git_checkout_options: GitVersionedOptions
{
  static var version: Int32 { return GIT_CHECKOUT_OPTIONS_VERSION }
  static var initializer: Initializer { return git_checkout_init_options }
  
  static func defaultOptions(strategy: git_checkout_strategy_t)
    -> git_checkout_options
  {
    var result = defaultOptions()
    
    result.checkout_strategy = strategy.rawValue
    return result
  }
}

extension git_fetch_options: GitVersionedOptions
{
  static var version: Int32 { return GIT_FETCH_OPTIONS_VERSION }
  static var initializer: Initializer { return git_fetch_init_options }
}

extension git_fetch_options
{
  public static func withOptions<T>(_ fetchOptions: FetchOptions,
                                    action: (git_fetch_options) throws -> T)
    rethrows -> T
  {
    var options = git_fetch_options.defaultOptions()
    
    options.prune = fetchOptions.pruneBranches ?
        GIT_FETCH_PRUNE : GIT_FETCH_NO_PRUNE
    options.download_tags = fetchOptions.downloadTags ?
        GIT_REMOTE_DOWNLOAD_TAGS_ALL : GIT_REMOTE_DOWNLOAD_TAGS_AUTO
    return try git_remote_callbacks.withCallbacks(fetchOptions.callbacks) {
      (callbacks) in
      options.callbacks = callbacks
      return try action(options)
    }
  }
}

fileprivate extension RemoteCallbacks
{
  static func fromPayload(_ payload: UnsafeMutableRawPointer?)
    -> UnsafeMutablePointer<RemoteCallbacks>?
  {
    return payload?.bindMemory(to: RemoteCallbacks.self, capacity: 1)
  }
}

extension git_remote_callbacks
{
  private enum Callbacks
  {
    static let credentials: git_cred_acquire_cb = {
      (cred, url, user, allowed, payload) in
      guard let callbacks = RemoteCallbacks.fromPayload(payload)
      else { return -1 }
      let allowed = git_credtype_t(allowed)
      
      if allowed.test(GIT_CREDTYPE_SSH_KEY) {
        let names = ["id_rsa", "github_rsa"]
        var result: Int32 = 1
        
        for name in names {
          let publicPath = "~/.ssh/\(name).pub".expandingTildeInPath
          let privatePath = "~/.ssh/\(name)".expandingTildeInPath
          
          result = git_cred_ssh_key_new(cred, user, publicPath, privatePath, "")
          if result == 0 {
            break
          }
        }
        return result
      }
      if allowed.test(GIT_CREDTYPE_USERPASS_PLAINTEXT) {
        let keychain = XTKeychain.shared
        let userName = user.map { String(cString: $0) } ?? ""
        
        if let urlString = url.flatMap({ String(cString: $0) }),
           let url = URL(string: urlString),
           let password = keychain.find(url: url, account: userName) ??
                          keychain.find(url: url.withPath(""),
                                        account: userName) {
          return git_cred_userpass_plaintext_new(cred, user, password)
        }
        if let (user, password) = callbacks.pointee.passwordBlock!() {
          return git_cred_userpass_plaintext_new(cred, user, password)
        }
      }
      // The documentation says to return >0 to indicate no credentials
      // acquired, but that leads to an assertion failure.
      return -1
    }
    
    static let transferProgress: git_transfer_progress_cb = {
      (stats, payload) in
      guard let callbacks = RemoteCallbacks.fromPayload(payload),
            let progress = stats?.pointee
      else { return -1 }
      let transferProgress = GitTransferProgress(gitProgress: progress)
      
      return callbacks.pointee.downloadProgress!(transferProgress) ? 0 : -1
    }
    
    static let pushTransferProgress: git_push_transfer_progress = {
      (current, total, bytes, payload) in
      guard let callbacks = RemoteCallbacks.fromPayload(payload)
      else { return -1 }
      let progress = PushTransferProgress(current: current, total: total,
                                          bytes: bytes)
      
      return callbacks.pointee.uploadProgress!(progress) ? 0 : -1
    }
  }
  
  /// Calls the given action with a populated callbacks struct.
  /// The "with" pattern is needed because of the need to make a mutable copy
  /// of the given callbacks as a payload, and perform the action within the
  /// scope of that copy.
  public static func withCallbacks<T>(_ callbacks: RemoteCallbacks,
                                      action: (git_remote_callbacks) throws -> T)
    rethrows -> T
  {
    var gitCallbacks = git_remote_callbacks.defaultOptions()
    var mutableCallbacks = callbacks
    
    gitCallbacks.payload = UnsafeMutableRawPointer(&mutableCallbacks)
    
    if callbacks.passwordBlock != nil {
      gitCallbacks.credentials = Callbacks.credentials
    }
    if callbacks.downloadProgress != nil {
      gitCallbacks.transfer_progress = Callbacks.transferProgress
    }
    if callbacks.uploadProgress != nil {
      gitCallbacks.push_transfer_progress = Callbacks.pushTransferProgress
    }
    return try action(gitCallbacks)
  }
}

extension git_merge_options: GitVersionedOptions
{
  static var version: Int32 { return GIT_MERGE_OPTIONS_VERSION }
  static var initializer: Initializer { return git_merge_init_options }
}

extension git_push_options: GitVersionedOptions
{
  static var version: Int32 { return GIT_PUSH_OPTIONS_VERSION }
  static var initializer: Initializer { return git_push_init_options }
}

extension git_remote_callbacks: GitVersionedOptions
{
  static var version: Int32 { return GIT_REMOTE_CALLBACKS_VERSION }
  static var initializer: Initializer { return git_remote_init_callbacks }
}

extension git_status_options: GitVersionedOptions
{
  static var version: Int32 { return GIT_STATUS_OPTIONS_VERSION }
  static var initializer: Initializer { return git_status_init_options }
}

extension git_stash_apply_options: GitVersionedOptions
{
  static var version: Int32 { return GIT_STASH_APPLY_OPTIONS_VERSION }
  static var initializer: Initializer { return git_stash_apply_init_options }
}

extension Array where Element == String
{
  /// Converts the given array to a `git_strarray` and calls the given block.
  /// This is patterned after `withArrayOfCStrings` except that function does
  /// not produce the necessary type.
  /// - parameter block: The block called with the resulting `git_strarray`. To
  /// use this array outside the block, use `git_strarray_copy()`.
  func withGitStringArray<T>(block: (git_strarray) -> T) -> T
  {
    let lengths = map { $0.utf8.count + 1 }
    let offsets = [0] + scan(lengths, 0, +)
    var buffer = [Int8]()
    
    buffer.reserveCapacity(offsets.last!)
    for string in self {
      buffer.append(contentsOf: string.utf8.map { Int8($0) })
      buffer.append(0)
    }
    
    let bufferSize = buffer.count
    
    return buffer.withUnsafeMutableBufferPointer {
      (pointer) -> T in
      let boundPointer = UnsafeMutableRawPointer(pointer.baseAddress!)
                         .bindMemory(to: Int8.self, capacity: bufferSize)
      var cStrings: [UnsafeMutablePointer<Int8>?] =
            offsets.map { boundPointer + $0 }
      
      cStrings[cStrings.count-1] = nil
      return cStrings.withUnsafeMutableBufferPointer {
        (arrayBuffer) -> T in
        let strarray = git_strarray(strings: arrayBuffer.baseAddress,
                                    count: count)
        
        return block(strarray)
      }
    }
  }
}

extension git_strarray: RandomAccessCollection
{
  public var startIndex: Int { return 0 }
  public var endIndex: Int { return count }
  
  public subscript(index: Int) -> String?
  {
    return self.strings[index].map { String(cString: $0) }
  }
}

extension Data
{
  func isBinary() -> Bool
  {
    return withUnsafeBytes {
      (data: UnsafeRawBufferPointer) -> Bool in
      return git_buffer_is_binary(data.bindMemory(to: Int8.self).baseAddress,
                                  count)
    }
  }
}
