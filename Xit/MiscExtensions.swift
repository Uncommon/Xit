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