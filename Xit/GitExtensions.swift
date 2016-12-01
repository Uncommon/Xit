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

extension git_checkout_options
{
  /// Returns a `git_checkout_options` struct initialized with default values.
  static func defaultOptions() -> git_checkout_options
  {
    var options = git_checkout_options()
    
    git_checkout_init_options(&options, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
    return options
  }
}
