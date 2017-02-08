import Foundation

protocol OID: CustomStringConvertible, Equatable
{
  var sha: String { get }
}

extension OID
{
  var description: String { return sha }
}

struct GitOID: OID
{
  let oid: git_oid
  
  static let shaLength = 40
  
  init(oid: git_oid)
  {
    self.oid = oid
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
  
  var sha: String
  {
    let storage = UnsafeMutablePointer<Int8>.allocate(capacity: GitOID.shaLength)
    var oid = self.oid
    
    git_oid_fmt(storage, &oid)
    return String(bytesNoCopy: storage, length: GitOID.shaLength,
                  encoding: .ascii, freeWhenDone: true) ?? ""
  }
}

func == (left: GitOID, right: GitOID) -> Bool
{
  var l = left.oid
  var r = right.oid
  
  return git_oid_equal(&l, &r) != 0
}
