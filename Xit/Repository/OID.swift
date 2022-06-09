import Foundation

public protocol OID: CustomDebugStringConvertible, Equatable, Sendable
{
  var sha: String { get }
  var isZero: Bool { get }
}

extension OID // CustomDebugStringConvertible
{
  public var debugDescription: String { sha }
}

// Don't explicitly conform to Hashable here because that constrains how the
// protocol can be used.
extension OID
{
  public func hash(into hasher: inout Hasher)
  {
    sha.hash(into: &hasher)
  }

  public func equals(_ other: (any OID)?) -> Bool
  {
    return sha == other?.sha
  }
}

func == (a: (any OID)?, b: (any OID)?) -> Bool
{
  switch (a, b) {
    case (nil, nil):
      return true
    case (.some, .none), (.none, .some):
      return false
    case let (.some(a), .some(b)):
      return a.equals(b)
  }
}

func != (a: (any OID)?, b: (any OID)?) -> Bool
{
  return !(a == b)
}


public protocol OIDObject: Equatable, Identifiable where ID: OID
{
}

extension OIDObject // Equatable
{
  public static func ==(a: Self, b: Self) -> Bool
  {
    return a.id == b.id
  }
}


public struct GitOID: OID
{
  var oid: git_oid
  
  static let shaLength = 40
  
  static func zero() -> GitOID
  {
    return .init(oid: git_oid())
  }
  
  init(oid: git_oid)
  {
    self.oid = oid
  }
  
  init(oidPtr: UnsafePointer<git_oid>)
  {
    self.oid = oidPtr.pointee
  }
  
  init(oidPtr: UnsafePointer<git_oid>?)
  {
    if let oidPtr = oidPtr {
      self.oid = oidPtr.pointee
    }
    else {
      self.oid = git_oid()
    }
  }
  
  init?(sha: String)
  {
    guard sha.lengthOfBytes(using: .ascii) == GitOID.shaLength
    else { return nil }
    
    var oid = git_oid()
    guard git_oid_fromstr(&oid, sha) == 0
    else { return nil }
    
    self.oid = oid
  }
  
  public var sha: String
  {
    let length = GitOID.shaLength + 1
    let storage = UnsafeMutablePointer<Int8>.allocate(capacity: length)
    var oid = self.oid
    defer {
      storage.deallocate()
    }
    
    git_oid_fmt(storage, &oid)
    // `git_oid_fmt()` doesn't add the terminator
    (storage + GitOID.shaLength).pointee = 0
    return String(cString: storage)
  }

  public var isZero: Bool
  { withUnsafeOID { git_oid_iszero($0) } == 1 }
  
  func withUnsafeOID<T>(_ block: (UnsafePointer<git_oid>) throws -> T) rethrows
    -> T
  {
    try withUnsafePointer(to: oid, block)
  }

  mutating func withUnsafeMutableOID<T>(
      _ block: (UnsafeMutablePointer<git_oid>) throws -> T) rethrows -> T
  {
    try withUnsafeMutablePointer(to: &oid, block)
  }
}

extension GitOID: Hashable
{
  public func hash(into hasher: inout Hasher)
  {
    withUnsafeBytes(of: oid) { buffer in
      hasher.combine(bytes: buffer)
    }
  }
}

extension GitOID: CustomStringConvertible
{
  public var description: String { sha }
}

public func == (left: GitOID, right: GitOID) -> Bool
{
  left.withUnsafeOID {
    (leftOID) in
    right.withUnsafeOID {
      (rightOID) in
      git_oid_equal(leftOID, rightOID) != 0
    }
  }
}
