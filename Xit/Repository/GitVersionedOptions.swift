import Foundation

/// Consolidates the logic of working with libgit2's versioned structures.
/// Construct with `git_thing.defaultOptions()`.
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
  static var version: Int32 { GIT_CHECKOUT_OPTIONS_VERSION }
  static var initializer: Initializer { git_checkout_init_options }
  
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
  static var version: Int32 { GIT_FETCH_OPTIONS_VERSION }
  static var initializer: Initializer { git_fetch_init_options }
}

extension git_merge_options: GitVersionedOptions
{
  static var version: Int32 { GIT_MERGE_OPTIONS_VERSION }
  static var initializer: Initializer { git_merge_init_options }
}

extension git_push_options: GitVersionedOptions
{
  static var version: Int32 { GIT_PUSH_OPTIONS_VERSION }
  static var initializer: Initializer { git_push_init_options }
}

extension git_remote_callbacks: GitVersionedOptions
{
  static var version: Int32 { GIT_REMOTE_CALLBACKS_VERSION }
  static var initializer: Initializer { git_remote_init_callbacks }
}

extension git_stash_apply_options: GitVersionedOptions
{
  static var version: Int32 { GIT_STASH_APPLY_OPTIONS_VERSION }
  static var initializer: Initializer { git_stash_apply_init_options }
}

extension git_status_options: GitVersionedOptions
{
  static var version: Int32 { GIT_STATUS_OPTIONS_VERSION }
  static var initializer: Initializer { git_status_init_options }
}
