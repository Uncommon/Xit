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
