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

extension git_merge_options
{
  static func defaultOptions() -> git_merge_options
  {
    var options = git_merge_options()
    
    git_merge_init_options(&options, UInt32(GIT_MERGE_OPTIONS_VERSION))
    return options
  }
}

extension Array where Element == String
{
  init(gitStrArray: git_strarray)
  {
    self.init()
  
    var stringPtr = gitStrArray.strings
    
    for _ in 0..<gitStrArray.count {
      guard let string = stringPtr?.pointee
      else { continue }
      
      append(String(cString: string))
      stringPtr = stringPtr?.advanced(by: 1)
    }
  }
  
  /// Converts the given array to a `git_strarray` and calls the given block.
  /// This is patterned after `withArrayOfCStrings` except that function does
  /// not produce the necessary type.
  /// - parameter block: The block called with the resulting `git_strarray`. To
  /// use this array outside the block, use `git_strarray_copy()`.
  func withGitStringArray(block: @escaping (git_strarray) -> Void)
  {
    let lengths = map { $0.utf8.count + 1 }
    let offsets = [0] + scan(lengths, 0, +)
    var buffer = [Int8]()
    
    buffer.reserveCapacity(offsets.last!)
    for string in self {
      buffer.append(contentsOf: string.utf8.map({ Int8($0) }))
      buffer.append(0)
    }
    
    buffer.withUnsafeMutableBufferPointer {
      (pointer) in
      let boundPointer = UnsafeMutableRawPointer(pointer.baseAddress!)
                         .bindMemory(to: Int8.self, capacity: buffer.count)
      var cStrings: [UnsafeMutablePointer<Int8>?] =
            offsets.map { boundPointer + $0 }
      
      cStrings[cStrings.count-1] = nil
      cStrings.withUnsafeMutableBufferPointer({
        (arrayBuffer) in
        let strarray = git_strarray(strings: arrayBuffer.baseAddress,
                                    count: count)
        
        block(strarray)
      })
    }
  }
}
