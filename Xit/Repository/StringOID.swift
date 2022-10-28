import Foundation

struct StringOID: OID, RawRepresentable
{
  let rawValue: String

  var sha: String { rawValue }
  var isZero: Bool { sha.isEmpty }
}

extension StringOID: Hashable
{
  func hash(into hasher: inout Hasher)
  {
    rawValue.hash(into: &hasher)
  }
}

extension StringOID: ExpressibleByStringLiteral
{
  init(stringLiteral value: StringLiteralType)
  {
    self.rawValue = value
  }
}

prefix operator §

prefix func § (sha: StringLiteralType) -> StringOID
{
  .init(rawValue: sha)
}
