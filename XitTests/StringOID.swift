import Foundation
@testable import Xit

struct StringOID: OID
{
  let sha: String
  var isZero: Bool { return sha == "00000000000000000000" }
}

extension StringOID: Equatable
{
}

func == (left: StringOID, right: StringOID) -> Bool
{
  return left.sha == right.sha
}

extension StringOID: Hashable
{
  public var hashValue: Int { return sha.hashValue }
}

prefix operator §

prefix func § (_ string: String) -> StringOID
{
  return StringOID(sha: string)
}
