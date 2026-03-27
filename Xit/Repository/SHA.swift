import Foundation

public struct SHA: RawRepresentable, Hashable, Sendable
{
  static let standardLength = 40

  public static var zero: SHA
  {
    .init(rawValue: String(repeating: "0", count: standardLength))!
  }

  public static var emptyTree: SHA
  {
    .init(rawValue: "4b825dc642cb6eb9a060e54bf8d69288fbee4904")!
  }

  public let rawValue: String

  public var shortString: String
  { String(rawValue.prefix(6)) }

  public init?(rawValue: String)
  {
    self.init(rawValue)
  }

  public init?(_ string: String)
  {
    guard Self.validate(string)
    else {
      return nil
    }

    self.rawValue = string
  }

  static func validate(_ string: String) -> Bool
  {
    guard string.count == SHA.standardLength
    else {
      return false
    }
    
    // Simple hex validation
    let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
    return string.unicodeScalars.allSatisfy { allowed.contains($0) }
  }
}

extension SHA: CustomStringConvertible
{
  public var description: String { rawValue }
}

extension SHA: ExpressibleByStringLiteral, ExpressibleByStringInterpolation
{
  public init(stringLiteral value: StringLiteralType)
  {
    if value.count < Self.standardLength {
      self.init(String(repeating: "0",
                       count: Self.standardLength - value.count) + value)!
    }
    else {
      self.init(value)!
    }
  }
}

extension SHA: Comparable
{
  public static func < (lhs: SHA, rhs: SHA) -> Bool
  {
    return lhs.rawValue < rhs.rawValue
  }
}
