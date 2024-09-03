import Foundation

prefix operator §

prefix func § (sha: StringLiteralType) -> GitOID
{
  .init(stringLiteral: sha)
}

extension GitOID: ExpressibleByStringLiteral
{
  public init(stringLiteral value: StringLiteralType)
  {
    self.init(string: value)
  }
}

extension GitOID
{
  static func random() -> GitOID
  {
    let digits = "0123456789ABCDEF"
    let shaString = String((0..<40).map { _ in  digits.randomElement()! })

    return .init(sha: shaString)!
  }
}
