import Foundation

public extension Sequence
{
  /// Returns the number of elements satisfying the predicate.
  func count(where predicate: (Element) -> Bool) -> Int
  {
    return reduce(0) { count, element in
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
    return enumerated().reduce(into: IndexSet()) { indices, pair in
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
    // Regular for loop yields IndexSet.Index rather than Int.
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
