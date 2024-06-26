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
    let padded = value + String(repeating: "0", count: GitOID.shaLength - value.count)

    self.oid = .init()
    precondition(git_oid_fromstr(&oid, padded) == 0, "failed to parse OID string")
  }
}

extension GitOID
{
  static func random() -> GitOID
  {
    .init(sha: String(UUID().uuidString.filter(\.isNumber).prefix(GitOID.shaLength)))!
  }
}
