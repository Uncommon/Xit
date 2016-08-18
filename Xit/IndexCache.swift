import Foundation

/// Maintains a cache of object indexes, where all indexes after a certain
/// value can be marked invalid.
class IndexCache<T: Hashable> {
  
  var cache = [T: Int]()
  var lastValidIndex: Int = -1
  
  /// Records the index for the given value. `index` should not be more than
  /// one greater than the last valid index.
  func setIndex(index: Int, forValue value: T)
  {
    cache[value] = index
    lastValidIndex = max(lastValidIndex, index)
  }
  
  /// Until new indexes are recorded, all values greater than or equal to
  /// `index` will be considered invalid and `indexOf()` will not return them.
  func invalidate(index index: Int)
  {
    if lastValidIndex >= index {
      lastValidIndex = index - 1
    }
  }
  
  /// Returns the recorded index of `value` if it is in the cache and its
  /// index has not been invalidated.
  func indexOf(value: T) -> Int?
  {
    guard let index = cache[value]
    else { return nil }
    
    return index <= lastValidIndex ? index : nil
  }
  
  func reset()
  {
    cache.removeAll()
    lastValidIndex = -1
  }
}
