import Foundation


// git_status_t is bridged as a struct instead of a raw UInt32.
extension git_status_t
{
  /// Returns true if the given flag is set.
  func test(_ flag: git_status_t) -> Bool
  {
    return (rawValue & flag.rawValue) != 0
  }
}

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
  init(fetchOptions: FetchOptions)
  {
    self.init()
    initializeWithVersion()
    
    prune = fetchOptions.pruneBranches ? GIT_FETCH_PRUNE : GIT_FETCH_NO_PRUNE
    download_tags = fetchOptions.downloadTags ? GIT_REMOTE_DOWNLOAD_TAGS_ALL
                                              : GIT_REMOTE_DOWNLOAD_TAGS_AUTO
    callbacks = git_remote_callbacks(callbacks: fetchOptions.callbacks)
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
  init(callbacks: RemoteCallbacks)
  {
    self.init()
    initializeWithVersion()

    var mutableCallbacks = callbacks
    
    self.payload = UnsafeMutableRawPointer(&mutableCallbacks)
    
    if callbacks.passwordBlock != nil {
      self.credentials = {
        (cred, url, user, allowed, payload) in
        guard let callbacks = RemoteCallbacks.fromPayload(payload)
        else { return -1 }
        
        if let (user, password) = callbacks.pointee.passwordBlock!() {
          return git_cred_userpass_plaintext_new(cred, user, password)
        }
        else {
          return 1
        }
      }
    }
    if callbacks.downloadProgress != nil {
      self.transfer_progress = {
        (stats, payload) in
        guard let callbacks = RemoteCallbacks.fromPayload(payload),
              let progress = stats?.pointee
        else { return -1 }
        let transferProgress = GitTransferProgress(gitProgress: progress)
        
        return callbacks.pointee.downloadProgress!(transferProgress) ? 0 : -1
      }
    }
    if callbacks.uploadProgress != nil {
      self.push_transfer_progress = {
        (current, total, bytes, payload) in
        guard let callbacks = RemoteCallbacks.fromPayload(payload)
        else { return -1 }
        let progress = PushTransferProgress(current: current, total: total,
                                            bytes: bytes)
        
        return callbacks.pointee.uploadProgress!(progress) ? 0 : -1
      }
    }
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
