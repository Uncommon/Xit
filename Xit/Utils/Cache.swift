import Foundation

/// A simple LRU key-value cache
class Cache<Key: Hashable, Value>
{
  private class Wrapper
  {
    var accessed: Date
    let object: Value
    
    init(object: Value)
    {
      self.object = object
      self.accessed = Date()
    }
    
    func touch()
    {
      accessed = Date()
    }
  }
  
  private var contents: [Key: Wrapper] = [:]
  private let mutex = Mutex()
  
  /// The maximum number of entries. If the maximum is exceeded, then entries
  /// are purged starting with the least recently accessed.
  public var maxSize: Int
  {
    didSet
    {
      mutex.withLock {
        purge(forAdditionalSpace: 0)
      }
    }
  }
  
  init(maxSize: Int)
  {
    self.maxSize = maxSize
  }
  
  /// This is the interface for accessing, adding and deleting entries.
  /// Accessing an entry updates its timestamp.
  subscript(key: Key) -> Value?
  {
    get
    {
      return mutex.withLock {
        guard let result = contents[key]
        else { return nil }
        
        result.touch()
        return result.object
      }
    }
    set
    {
      mutex.withLock {
        purge(forAdditionalSpace: 1)
        contents[key] = newValue.map { Wrapper(object: $0) }
      }
    }
  }
  
  private func purge(forAdditionalSpace space: Int)
  {
    while contents.count + space > maxSize {
      if let oldest = contents.min(by: { $0.value.accessed < $1.value.accessed }) {
        contents[oldest.key] = nil
      }
    }
  }
}
