import Foundation
import Combine
import UniformTypeIdentifiers

public extension XMLElement
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

public extension Publisher
{
  /// For each published element, `object`'s `keyPath` is set to `nil`, and then
  /// a `debounce` is applied on the main queue.
  func debounce<T, O>(
    afterInvalidating object: T,
    keyPath: ReferenceWritableKeyPath<T, O?>,
    delay: DispatchQueue.SchedulerTimeType.Stride = 0.25)
    -> Publishers.Debounce<Publishers.HandleEvents<Self>, DispatchQueue>
    where T: AnyObject
  {
    return handleEvents(receiveOutput: { _ in
      object[keyPath: keyPath] = nil
    }).debounce(for: delay, scheduler: DispatchQueue.main)
  }
}

public extension Sequence
{
  /// Returns the number of elements satisfying the predicate.
  func count(where predicate: (Element) -> Bool) -> Int
  {
    return reduce(0) {
      (count, element) -> Int in
      predicate(element) ? count + 1 : count
    }
  }
}

public extension Sequence where Element: NSObject
{
  /// Returns true if the sequence contains an object where `isEqual`
  /// returns true.
  func containsEqualObject(_ object: NSObject) -> Bool
  {
    return contains { $0.isEqual(object) }
  }
}

public extension Collection
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

public extension Array
{
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

  func firstOfType<T>() -> T?
  {
    for value in self {
      if let t = value as? T {
        return t
      }
    }
    return nil
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

public extension Sequence where Iterator.Element: Hashable
{
  func unique() -> [Iterator.Element]
  {
    var seen: Set<Iterator.Element> = []

    return filter { seen.insert($0).inserted }
  }
}

public extension Sequence
{
  func sorted<T>(byKeyPath keyPath: KeyPath<Element, T>) -> [Element]
    where T: Comparable
  {
    sorted(by: { $0[keyPath: keyPath] < $1[keyPath: keyPath] })
  }
}

public extension NSMutableArray
{
  func sort(keyPath key: String, ascending: Bool = true)
  {
    self.sort(using: [NSSortDescriptor(key: key, ascending: ascending)])
  }
}

public extension Thread
{
  /// Performs the block immediately if this is the main thread, or
  /// synchronosly on the main thread otherwise.
  static func syncOnMain<T>(_ block: () throws -> T) rethrows -> T
  {
    return isMainThread ? try block()
      : try DispatchQueue.main.sync(execute: block)
  }
}

public extension DecodingError
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

public extension NSObject
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

public extension TimeInterval
{
  static let minutes: TimeInterval = 60
}

public extension UTType
{
  /// Returns the type for the given extension, or `.item` if none found.
  static func fromExtension(_ ext: String) -> UTType
  {
    .init(filenameExtension: ext) ?? .item
  }
}

// Swift 3 took away ++, but it still can be useful.
postfix operator ++

public extension Strideable where Stride == Int
{
  static postfix func ++ (i: inout Self) -> Self
  {
    let result = i
    i = i.advanced(by: 1)
    return result
  }
}

infix operator <~

public extension String
{
  static func <~ (a: String, b: String) -> Bool
  {
    return a.localizedStandardCompare(b) == .orderedAscending
  }
}

public extension RawRepresentable where RawValue == String
{
  static func <~ (a: Self, b: Self) -> Bool
  {
    return a.rawValue.localizedStandardCompare(b.rawValue) == .orderedAscending
  }
}

public extension Timer
{
  static func mainScheduledTimer(
    withTimeInterval interval: TimeInterval,
    repeats: Bool,
    block: @escaping @Sendable @MainActor (Timer) -> Void
  ) -> Timer
  {
    let timer = Timer(timeInterval: interval, repeats: repeats) {
      (timer) in
      MainActor.assumeIsolated { block(timer) }
    }

    RunLoop.main.add(timer, forMode: .default)
    return timer
  }
}

// Reportedly this is hidden in the Swift runtime
// https://oleb.net/blog/2016/10/swift-array-of-c-strings/
public func withArrayOfCStrings<R>(
  _ args: [String],
  _ body: ([UnsafeMutablePointer<CChar>?]) -> R) -> R
{
  let argsCounts = args.map { $0.utf8.count + 1 }
  let argsOffsets = argsCounts.reduce(into: [0]) { offsets, count in
    offsets.append(offsets.last! + count)
  }
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
    cStrings[cStrings.count - 1] = nil
    return body(cStrings)
  }
}
