import Foundation

/// A simple LRU key-value cache
class Cache<Key: Hashable, Value>
{
  class Wrapper
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
  
  func purge(forAdditionalSpace space: Int)
  {
    while contents.count + space > maxSize {
      if let oldest = contents.min(by: { $0.value.accessed < $1.value.accessed }) {
        contents[oldest.key] = nil
      }
    }
  }
}
