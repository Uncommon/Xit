import Foundation

extension URL
{
  /// Returns a copy of the URL with its path replaced
  func withPath(_ path: String) -> URL
  {
    guard var components = URLComponents(url: self,
                                         resolvingAgainstBaseURL: false)
    else { return self }
    
    components.path = path
    return components.url ?? self
  }
  
  /// Returns the default port based on the URL's scheme
  var defaultPort: Int
  {
    switch scheme {
      case "https":
        return 443
      case "ssh":
        return 22
      case "git":
        return 9418
      default:
        return 80
    }
  }
}

extension XMLElement
{
  /// Returns the element's attributes as a dictionary.
  func attributesDict() -> [String: String]
  {
    guard let attributes = attributes
    else { return [:] }
    
    var result = [String: String]()
    
    for attribute in attributes {
      guard let name = attribute.name,
            let value = attribute.stringValue
      else { continue }
      
      result[name] = value
    }
    return result
  }
  
  /// Returns a list of attribute values of all children, matching the given
  /// attribute name.
  func childrenAttributes(_ name: String) -> [String]
  {
    return children?.compactMap {
      ($0 as? XMLElement)?.attribute(forName: name)?.stringValue
    } ?? []
  }
}

extension Sequence
{
  /// Returns the number of elements satisfying the predicate.
  func count(where predicate: (Element) -> Bool) -> Int
  {
    return reduce(0) {
      (count, element) -> Int in
      return predicate(element) ? count + 1 : count
    }
  }
}

extension Sequence where Element: NSObject
{
  /// Returns true if the sequence contains an object where `isEqual`
  /// returns true.
  func containsEqualObject(_ object: NSObject) -> Bool
  {
    return contains { $0.isEqual(object) }
  }
}

extension Collection
{
  /// Returns the index of each item satisfying the condition.
  func indices(where condition: (Element) -> Bool) -> IndexSet
  {
    return enumerated().reduce(into: IndexSet()) {
      (indices, pair) in
      if condition(pair.element) {
        indices.update(with: pair.offset)
      }
    }
  }
}

extension Array
{
  /// Assuming the array is sorted, returns the insertion index for the given
  /// item to be inserted in order.
  func sortedInsertionIndex(of elem: Element,
                            isOrderedBefore: (Element, Element) -> Bool)
                            -> Int
  {
    var lo = 0
    var hi = self.count - 1
    
    while lo <= hi {
      let mid = (lo + hi)/2
      
      if isOrderedBefore(self[mid], elem) {
        lo = mid + 1
      }
      else if isOrderedBefore(elem, self[mid]) {
        hi = mid - 1
      }
      else {
        return mid
      }
    }
    return lo
  }
  
  func objects(at indexSet: IndexSet) -> [Element]
  {
    return indexSet.compactMap { $0 < count ? self[$0] : nil }
  }
  
  mutating func removeObjects(at indexSet: IndexSet)
  {
    self = enumerated().filter { !indexSet.contains($0.offset) }
                       .map { $0.element }
  }
  
  mutating func insert<S>(_ elements: S, at indexSet: IndexSet)
    where S: Sequence, S.Element == Element
  {
    for (element, index) in zip(elements, indexSet) {
      insert(element, at: index)
    }
  }
  
  mutating func insert<S>(from otherSequence: S, indices: IndexSet)
    where S: Collection, S.Element == Element, S.Index == Int
  {
    // Regular for loop yields IndexSet.Index rather than Int
    indices.forEach {
      insert(otherSequence[$0], at: $0)
    }
  }
  
  /// Returns the first non-nil result of calling `predicate` on the array's
  /// elements.
  func firstResult<T>(_ predicate: (Element) -> T?) -> T?
  {
    return lazy.compactMap(predicate).first
  }

  func firstOfType<T>() -> T?
  {
    return firstResult { $0 as? T }
  }
  
  func firstOfType<T>(where condition: (T) -> Bool) -> T?
  {
    for value in self {
      guard let t = value as? T
      else { continue }
      
      if condition(t) {
        return t
      }
    }
    return nil
  }
}

extension Array where Element: Comparable
{
  mutating func insertSorted(_ newElement: Element)
  {
    insert(newElement,
           at: sortedInsertionIndex(of: newElement) { $0 < $1 })
  }
}

extension NSMutableArray
{
  func sort(keyPath key: String, ascending: Bool = true)
  {
    self.sort(using: [NSSortDescriptor(key: key, ascending: ascending)])
  }
}

extension Thread
{
  /// Performs the block immediately if this is the main thread, or
  /// asynchronosly on the main thread otherwise.
  static func performOnMainThread(_ block: @escaping () -> Void)
  {
    if isMainThread {
      block()
    }
    else {
      DispatchQueue.main.async(execute: block)
    }
  }
  
  /// Performs the block immediately if this is the main thread, or
  /// synchronosly on the main thread otherwise.
  static func syncOnMainThread<T>(_ block: () throws -> T) rethrows -> T
  {
    return isMainThread ? try block()
                        : try DispatchQueue.main.sync(execute: block)
  }
}

extension DecodingError
{
  var context: Context
  {
    switch self {
      case .dataCorrupted(let context):
        return context
      case .keyNotFound(_, let context):
        return context
      case .typeMismatch(_, let context):
        return context
      case .valueNotFound(_, let context):
        return context
      @unknown default:
        return Context(codingPath: [], debugDescription: "")
    }
  }
}

extension NSObject
{
  func withSync<T>(block: () throws -> T) rethrows -> T
  {
    objc_sync_enter(self)
    defer {
      objc_sync_exit(self)
    }
    return try block()
  }
}

extension NSMenu
{
  func item(withTarget target: Any?, andAction action: Selector?) -> NSMenuItem?
  {
    let index = indexOfItem(withTarget: target, andAction: action)
    
    return index == -1 ? nil : items[index]
  }
}

extension TimeInterval
{
  static let minutes: TimeInterval = 60
}

// Swift 3 took away ++, but it still can be useful.
postfix operator ++

extension UInt
{
  static postfix func ++ (i: inout UInt) -> UInt
  {
    let result = i
    i += 1
    return result
  }
}

infix operator <~

extension String
{
  static func <~ (a: String, b: String) -> Bool
  {
    return a.localizedStandardCompare(b) == .orderedAscending
  }
}

// Reportedly this is hidden in the Swift runtime
// https://oleb.net/blog/2016/10/swift-array-of-c-strings/
public func withArrayOfCStrings<R>(
    _ args: [String],
    _ body: ([UnsafeMutablePointer<CChar>?]) -> R) -> R
{
  let argsCounts = Array(args.map { $0.utf8.count + 1 })
  let argsOffsets = [ 0 ] + scan(argsCounts, 0, +)
  let argsBufferSize = argsOffsets.last!
  
  var argsBuffer: [UInt8] = []
  argsBuffer.reserveCapacity(argsBufferSize)
  for arg in args {
    argsBuffer.append(contentsOf: arg.utf8)
    argsBuffer.append(0)
  }
  
  return argsBuffer.withUnsafeMutableBufferPointer {
    (argsBuffer) in
    let ptr = UnsafeMutableRawPointer(argsBuffer.baseAddress!).bindMemory(
              to: CChar.self, capacity: argsBuffer.count)
    var cStrings: [UnsafeMutablePointer<CChar>?] = argsOffsets.map { ptr + $0 }
    cStrings[cStrings.count-1] = nil
    return body(cStrings)
  }
}

// from SwiftPrivate
public func scan<S: Sequence, U>(
    _ seq: S,
    _ initial: U,
    _ combine: (U, S.Iterator.Element) -> U) -> [U]
{
  var result: [U] = []
  var runningResult = initial
  
  result.reserveCapacity(seq.underestimatedCount)
  for element in seq {
    runningResult = combine(runningResult, element)
    result.append(runningResult)
  }
  return result
}
