import Foundation

public protocol OID: CustomDebugStringConvertible, Hashable, Sendable
{
  var sha: String { get }
  var isZero: Bool { get }
  
  /// This is a workaround for the compiler being too eager to use
  /// `== (a: (any OID)?, b: (any OID)?)` when a more specific (and more
  /// efficient) version is available.
  func equalsSame(_ other: Self) -> Bool
}

extension OID // CustomDebugStringConvertible
{
  public var debugDescription: String { sha }
}

extension OID
{
  public func hash(into hasher: inout Hasher)
  {
    sha.hash(into: &hasher)
  }

  /// For use when it isn't statically known that two OID values are the same type
  public func equals(_ other: (any OID)?) -> Bool
  {
    return sha == other?.sha
  }
  
  public func equalsSame(_ other: Self) -> Bool
  {
    return sha == other.sha
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


public protocol OIDObject: Hashable, Identifiable where ID: OID
{
}

extension OIDObject // Hashable
{
  public func hash(into hasher: inout Hasher)
  { id.hash(into: &hasher) }
}

extension OIDObject // Equatable
{
  public static func == (a: Self, b: Self) -> Bool
  { a.id == b.id }
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
  
  public func equalsSame(_ other: GitOID) -> Bool
  {
    withUnsafeOID {
      (leftOID) in
      other.withUnsafeOID {
        (rightOID) in
        git_oid_equal(leftOID, rightOID) != 0
      }
    }
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

extension GitOID: CustomDebugStringConvertible
{
  public var debugDescription: String { .init(sha.drop(while: { $0 == "0" })) }
}

let oidSize = 20

public func == (left: GitOID, right: GitOID) -> Bool
{
  left.withUnsafeOID {
    (leftOID) in
    right.withUnsafeOID {
      (rightOID) in
      // git_oid_equal() is slowed down by the use of git_oid_size(), which isn't
      // even needed with SHA256 support turned off
      memcmp(leftOID, rightOID, oidSize) == 0
    }
  }
}

public func != (left: GitOID, right: GitOID) -> Bool
{ !(left == right) }
