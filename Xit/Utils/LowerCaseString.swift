import Foundation
import SwiftUI

/// Stores a string that is guaranteed to be lower case, for convenience in
/// case-insensitive searching and filtering.
public struct LowerCaseString
{
  public let rawValue: String

  public var isEmpty: Bool { rawValue.isEmpty }

  public init(_ string: String)
  {
    self.rawValue = string.lowercased()
  }

  public init()
  {
    self.rawValue = ""
  }

  /// Returns true if the given string contains this string, using a case
  /// insensitive comparison.
  public func isSubString(of string: String) -> Bool
  {
    string.lowercased().contains(rawValue)
  }
}

extension LowerCaseString: RawRepresentable
{
  public init?(rawValue: String)
  {
    self.init(rawValue)
  }
}

extension LowerCaseString: ExpressibleByStringLiteral
{
  public init(stringLiteral: StringLiteralType)
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
