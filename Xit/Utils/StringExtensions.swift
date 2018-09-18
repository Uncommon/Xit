import Foundation

extension String
{
  init?(data: Data, usedEncoding: inout String.Encoding)
  {
    let encodings: [String.Encoding] = [.utf8, .utf16, .isoLatin1, .isoLatin2,
                                        .macOSRoman, .windowsCP1252]
    
    for encoding in encodings {
      if let string = String(data: data, encoding: encoding) {
        self = string
        return
      }
    }
    return nil
  }

  var trimmingWhitespace: String
  {
    return trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  var nilIfEmpty: String?
  {
    return isEmpty ? nil : self
  }
  
  /// Splits a "refs/*/..." string into prefix and remainder.
  func splitRefName() -> (String, String)?
  {
    guard hasPrefix("refs/")
      else { return nil }
    
    let start = index(startIndex, offsetBy: "refs/".count)
    guard let slashRange = range(of: "/", options: [], range: start..<endIndex,
                                 locale: nil)
      else { return nil }
    let slashIndex = index(slashRange.lowerBound, offsetBy: 1)
    
    return (String(self[..<slashIndex]),
            String(self[slashRange.upperBound...]))
  }
  
  /// Splits the string into an array of lines.
  func lineComponents() -> [String]
  {
    var lines: [String] = []
    
    enumerateLines { (line, _) in lines.append(line) }
    return lines
  }
  
  enum LineEndingStyle: String
  {
    case crlf
    case lf
    case unknown
    
    var string: String
    {
      switch self
      {
      case .crlf: return "\r\n"
      case .lf:   return "\n"
      case .unknown: return "\n"
      }
    }
  }
  
  var lineEndingStyle: LineEndingStyle
  {
    if range(of: "\r\n") != nil {
      return .crlf
    }
    if range(of: "\n") != nil {
      return .lf
    }
    return .unknown
  }
  
  var xmlEscaped: String
  {
    return CFXMLCreateStringByEscapingEntities(kCFAllocatorDefault,
                                               self as CFString,
                                               [:] as CFDictionary) as String
  }
}

// MARK: Prefixes & Suffixes
extension String
{
  /// Returns the string with the given prefix removed, or returns the string
  /// unchanged if the prefix does not match.
  func removingPrefix(_ prefix: String) -> String
  {
    guard hasPrefix(prefix)
      else { return self }
    
    return String(self[prefix.endIndex...])
  }
  
  /// Returns the string with the given suffix removed, or returns the string
  /// unchanged if the suffix does not match.
  func removingSuffix(_ suffix: String) -> String
  {
    guard hasSuffix(suffix)
      else { return self }
    
    return String(dropLast(suffix.count))
  }
  
  /// Returns the string with the given prefix, adding it only if necessary.
  func withPrefix(_ prefix: String) -> String
  {
    if hasPrefix(prefix) {
      return self
    }
    else {
      return prefix.appending(self)
    }
  }
  
  /// Returns the string with the given suffix, adding it only if necessary.
  func withSuffix(_ suffix: String) -> String
  {
    if hasSuffix(suffix) {
      return self
    }
    else {
      return appending(suffix)
    }
  }
}

// MARK: Paths
extension String
{
  func appending(pathComponent component: String) -> String
  {
    return (self as NSString).appendingPathComponent(component)
  }
  
  var pathExtension: String
  {
    return (self as NSString).pathExtension
  }

  var pathComponents: [String]
  {
    return (self as NSString).pathComponents
  }
  
  // TODO: this probably shouldn't be optional
  var firstPathComponent: String?
  {
    return pathComponents.first
  }
  
  var deletingFirstPathComponent: String
  {
    return NSString.path(withComponents: Array(pathComponents.dropFirst(1)))
  }
  
  var lastPathComponent: String
  {
    return (self as NSString).lastPathComponent
  }
  
  var deletingLastPathComponent: String
  {
    return (self as NSString).deletingLastPathComponent
  }
}
