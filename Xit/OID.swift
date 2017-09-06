import Foundation

// This protocol "can only be used as a generic constraint" because Hashable
// inherits from Equatable which uses Self.
public protocol OID: Hashable
{
  var sha: String { get }
}

extension OID
{
  public var hashValue: Int { return sha.hashValue }
}

public struct GitOID: OID, Hashable
{
  let oid: git_oid
  
  static let shaLength = 40
  
  static func zero() -> GitOID
  {
    return GitOID(oid: git_oid())
  }
  
  init(oid: git_oid)
  {
    self.oid = oid
  }
  
  init(oidPtr: UnsafePointer<git_oid>)
  {
    self.oid = oidPtr.pointee
  }
  
  init?(sha: String)
  {
    if sha.lengthOfBytes(using: .ascii) != GitOID.shaLength {
      return nil
    }
    
    let oidPtr = UnsafeMutablePointer<git_oid>.allocate(capacity: 1)
    defer {
      oidPtr.deallocate(capacity: 1)
    }
    
    guard git_oid_fromstr(oidPtr, sha) == GIT_OK.rawValue
    else { return nil }
    
    oid = oidPtr.pointee
  }
  
  public var sha: String
  {
    let storage = UnsafeMutablePointer<Int8>.allocate(capacity: GitOID.shaLength)
    var oid = self.oid
    
    git_oid_fmt(storage, &oid)
    return String(bytesNoCopy: storage, length: GitOID.shaLength,
                  encoding: .ascii, freeWhenDone: true) ?? ""
  }
  
  public var hashValue: Int
  {
    // Unfortunately you can't iterate through a tuple
    var result = Int(oid.id.19)
    
    result = (result << 8) | Int(oid.id.18)
    result = (result << 8) | Int(oid.id.17)
    result = (result << 8) | Int(oid.id.16)
    result = (result << 8) | Int(oid.id.15)
    result = (result << 8) | Int(oid.id.14)
    result = (result << 8) | Int(oid.id.13)
    result = (result << 8) | Int(oid.id.12)
    result = (result << 8) | Int(oid.id.11)
    result = (result << 8) | Int(oid.id.10)
    result = (result << 8) | Int(oid.id.9)
    result = (result << 8) | Int(oid.id.8)
    result = (result << 8) | Int(oid.id.7)
    result = (result << 8) | Int(oid.id.6)
    result = (result << 8) | Int(oid.id.5)
    result = (result << 8) | Int(oid.id.4)
    result = (result << 8) | Int(oid.id.3)
    result = (result << 8) | Int(oid.id.2)
    result = (result << 8) | Int(oid.id.1)
    result = (result << 8) | Int(oid.id.0)
    return Int(result)
  }
  
  public var isZero: Bool
  {
    return git_oid_iszero(unsafeOID()) == 1
  }
  
  func unsafeOID() -> UnsafePointer<git_oid>
  {
    let ptr = UnsafeMutablePointer<git_oid>.allocate(capacity: 1)
    
    ptr.pointee = oid
    return UnsafePointer<git_oid>(ptr)
  }
}

extension GitOID: CustomStringConvertible
{
  public var description: String { return sha }
}

public func == (left: GitOID, right: GitOID) -> Bool
{
  var l = left.oid
  var r = right.oid
  
  return git_oid_equal(&l, &r) != 0
}
