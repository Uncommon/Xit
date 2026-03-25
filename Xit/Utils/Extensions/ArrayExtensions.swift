import Foundation

public extension Array
{
  /// Assuming the array is sorted, returns the insertion index for the given
  /// item to be inserted in order.
  func sortedInsertionIndex(of elem: Element,
                            isOrderedBefore: (Element, Element) -> Bool) -> Int
  {
    var lo = startIndex
    var hi = index(before: endIndex)

    while lo <= hi {
      let mid = (lo + hi) / 2

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

  /// Returns the first non-nil result of calling `predicate` on the array's
  /// elements.
  func firstResult<T>(_ predicate: (Element) -> T?) -> T?
  {
    // We immediately consume `compactMap` so the predicate does not escape.
    return withoutActuallyEscaping(predicate) { lazy.compactMap($0).first }
  }
}

public extension Array where Element: Comparable
{
  mutating func insertSorted(_ newElement: Element)
  {
    insert(newElement,
           at: sortedInsertionIndex(of: newElement) { $0 < $1 })
  }
}
