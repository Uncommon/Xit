import Foundation

extension String
{
  /// Returns the string with the given prefix removed, or returns the string
  /// unchanged if the prefix does not match.
  func stringByRemovingPrefix(_ prefix: String) -> String
  {
    guard hasPrefix(prefix)
    else { return self }
    
    return self.substring(from: prefix.characters.endIndex)
  }
  
  func stringByAppendingPathComponent(_ component: String) -> String
  {
    return (self as NSString).appendingPathComponent(component)
  }
  
  var stringByDeletingLastPathComponent: String
  {
    return (self as NSString).deletingLastPathComponent
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
    return children?.flatMap({
      ($0 as? XMLElement)?.attribute(forName: name)?.stringValue
    }) ?? []
  }
}

extension NSView
{
  /// Follows the superview chain and returns the highest ancestor.
  var firstAncestor: NSView?
  {
    var ancestor = superview
    
    while ancestor?.superview != nil {
      ancestor = ancestor?.superview
    }
    return ancestor
  }
  
  /// Returns the window for the view's first ancestor. For example, if a view
  /// is in a hidden tab, its own `window` will be `null`, but this will still
  /// return the real window.
  var ancestorWindow: NSWindow?
  {
    return firstAncestor?.window
  }
}

extension NSButton
{
  /// The intValue property interpreted as a Bool.
  var boolValue: Bool
  {
    get { return intValue != 0 }
    set { intValue = newValue ? 1 : 0 }
  }
}

extension String
{
  /// Splits a "refs/*/..." string into prefix and remainder.
  func splitRefName() -> (String, String)?
  {
    guard hasPrefix("refs/")
    else { return nil }
    
    let start = characters.index(startIndex, offsetBy: "refs/".characters.count)
    guard let slashRange = range(of: "/", options: [], range: start..<endIndex,
                                 locale: nil)
    else { return nil }
    let slashIndex = index(slashRange.lowerBound, offsetBy: 1)
    
    return (substring(to: slashIndex),
            substring(from: slashRange.upperBound))
  }
}

extension NSTableView
{
  /// Returns a set of all visible row indexes
  func visibleRows() -> IndexSet
  {
    return IndexSet(integersIn: rows(in: visibleRect).toRange() ?? 0..<0)
  }
  
  func scrollRowToCenter(_ row: Int)
  {
    guard let viewRect = superview?.frame
    else { return }
    let rowRect = rect(ofRow: row)
    var scrollOrigin = rowRect.origin
    
    scrollOrigin.y += (rowRect.size.height - viewRect.size.height)/2
    if scrollOrigin.y < 0 {
      scrollOrigin.y = 0
    }
    superview?.animator().setBoundsOrigin(scrollOrigin)
  }
}

extension Array
{
  /// Assuming the array is sorted, returns the insertion index for the given
  /// item to be inserted in order.
  func sortedInsertionIndex(of elem: Element,
                            isOrderedBefore: (Element, Element) -> Bool)
                            -> Int {
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
}

extension Array where Element: Comparable
{
  mutating func insertSorted(_ newElement: Element)
  {
    insert(newElement,
           at: sortedInsertionIndex(of: newElement,
                                    isOrderedBefore: { $0 < $1 }))
  }
}

// Swift 3 took away ++, but it still can be useful.
postfix operator ++

extension UInt
{
  static postfix func ++ (i: inout UInt) -> UInt
  {
    let result = i
    i = i + 1
    return result
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
