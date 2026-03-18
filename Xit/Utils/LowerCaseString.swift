import SwiftUI

/// Stores a string that is guaranteed to be lower case, for convenience in
/// case-insensitive searching and filtering.
struct LowerCaseString
{
  let rawValue: String
  
  var isEmpty: Bool { rawValue.isEmpty }
  
  init(_ string: String)
  {
    self.rawValue = string.lowercased()
  }
  
  init()
  {
    self.rawValue = ""
  }
  
  /// Returns true if the given string contains this string, using a case
  /// insensitive comparison.
  func isSubString(of string: String) -> Bool
  {
    string.lowercased().contains(rawValue)
  }
}

extension LowerCaseString: RawRepresentable
{
  init?(rawValue: String)
  {
    self.init(rawValue)
  }
}

extension LowerCaseString: ExpressibleByStringLiteral
{
  init(stringLiteral: StringLiteralType)
  {
    self.rawValue = .init(stringLiteral: stringLiteral.lowercased())
  }
}

extension Binding
{
  /// Creates a `Binding` that converts a `String` to a `LowerCaseString`.
  static func lowerCaseString<Root: AnyObject>(
    _ root: Root,
    _ keyPath: ReferenceWritableKeyPath<Root, LowerCaseString>) -> Binding<String>
  {
    .init {
      root[keyPath: keyPath].rawValue
    } set: {
      root[keyPath: keyPath] = .init($0)
    }
  }
}
