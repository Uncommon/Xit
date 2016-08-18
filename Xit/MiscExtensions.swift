import Foundation

extension String {
  
  /// Returns the string with the given prefix removed, or returns the string
  /// unchanged if the prefix does not match.
  func stringByRemovingPrefix(prefix: String) -> String
  {
    guard hasPrefix(prefix)
    else { return self }
    
    return self.substringFromIndex(prefix.characters.endIndex)
  }
}

extension NSXMLElement {
  
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
  func childrenAttributes(name: String) -> [String]
  {
    return children?.flatMap({
      ($0 as? NSXMLElement)?.attributeForName(name)?.stringValue
    }) ?? []
  }
}

extension String {
  /// Splits a "refs/*/..." string into prefix and remainder.
  func splitRefName() -> (String, String)?
  {
    guard hasPrefix("refs/")
    else { return nil }
    
    let start = startIndex.advancedBy("refs/".characters.count)
    guard let slashRange = rangeOfString("/", options: [], range: start..<endIndex, locale: nil)
    else { return nil }
    
    return (substringToIndex(slashRange.startIndex.successor()),
            substringFromIndex(slashRange.endIndex))
  }
}

extension NSTableView {
  /// Returns a set of all visible row indexes
  func visibleRows() -> NSIndexSet
  {
    return NSIndexSet(indexesInRange: rowsInRect(visibleRect))
  }
}