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
    let padded = String(repeating: "0",
                        count: GitOID.shaLength - value.count) + value

    self.oid = .init()
    precondition(git_oid_fromstr(&oid, padded) == 0, "failed to parse OID string")
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
