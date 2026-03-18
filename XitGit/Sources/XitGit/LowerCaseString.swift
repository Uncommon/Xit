import Foundation

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
