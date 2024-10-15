import Foundation
import RegexBuilder

public struct SHA: RawRepresentable, Hashable
{
  static let standardLength = 40

  static var zero: SHA
  {
    .init(rawValue: String(repeating: "0", count: standardLength))!
  }

  static var emptyTree: SHA
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
    let regex = Regex {
      OneOrMore(.hexDigit)
    }
    guard (try? regex.wholeMatch(in: string)) != nil
    else {
      return false
    }

    return true
  }
}

extension SHA: ExpressibleByStringLiteral
{
  public init(stringLiteral value: StringLiteralType)
  {
    self.init(value)!
  }
}
