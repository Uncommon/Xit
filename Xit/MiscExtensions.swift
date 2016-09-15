import Foundation

extension String {
  
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

extension XMLElement {
  
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

extension NSButton {
  
  /// The intValue property interpreted as a Bool.
  var boolValue: Bool
  {
    get { return intValue != 0 }
    set { intValue = newValue ? 1 : 0 }
  }
}

extension String {
  /// Splits a "refs/*/..." string into prefix and remainder.
  func splitRefName() -> (String, String)?
  {
    guard hasPrefix("refs/")
    else { return nil }
    
    let start = characters.index(startIndex, offsetBy: "refs/".characters.count)
    guard let slashRange = range(of: "/", options: [], range: start..<endIndex, locale: nil)
    else { return nil }
    
    return (substring(to: characters.index(before: slashRange.lowerBound)),
            substring(from: slashRange.upperBound))
  }
}

extension NSTableView {
  /// Returns a set of all visible row indexes
  func visibleRows() -> IndexSet
  {
    return IndexSet(integersIn: rows(in: visibleRect).toRange() ?? 0..<0)
  }
}

// Swift 3 took away ++, but it still can be useful.
postfix operator ++

extension UInt {
  static postfix func ++ (i: inout UInt) -> UInt
  {
    let result = i
    i = i + 1
    return result
  }
}
