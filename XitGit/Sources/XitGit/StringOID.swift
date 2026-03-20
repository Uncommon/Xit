import Foundation
import Clibgit2

prefix operator §

public prefix func § (sha: StringLiteralType) -> GitOID
{
  .init(stringLiteral: sha)
}

extension GitOID: ExpressibleByStringLiteral, ExpressibleByStringInterpolation
{
  public init(stringLiteral value: StringLiteralType)
  {
    self.init(sha: SHA(stringLiteral: value))!
  }
}

public extension GitOID
{
  static func random() -> GitOID
  {
    let digits = "0123456789ABCDEF"
    let shaString = String((0..<40).map { _ in  digits.randomElement()! })

    return .init(sha: SHA(shaString)!)!
  }
}
