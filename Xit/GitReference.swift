import Foundation

public protocol Reference
{
  /// For a direct reference, the target OID
  var targetOID: OID? { get }
  /// Peels a tag reference
  var peeledTargetOID: OID? { get }
  /// For a symbolic reference, the name of the target
  var symbolicTargetName: String? { get }
  /// Type of reference: oid (direct) or symbolic
  var type: ReferenceType { get }
  /// The reference name
  var name: String { get }
  
  /// Peels a symbolic reference until a direct reference is reached
  func resolve() -> Reference?
}

class GitReference: Reference
{
  let ref: OpaquePointer
  
  init(reference: OpaquePointer)
  {
    self.ref = reference
  }
  
  init?(name: String, repository: OpaquePointer)
  {
    let ref = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let result = git_reference_lookup(ref, repository, name)
    guard result == 0,
          let finalRef = ref.pointee
    else { return nil }
    
    self.ref = finalRef
  }
  
  init?(headForRepo repo: OpaquePointer)
  {
    let ref = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let result = git_repository_head(ref, repo)
    guard result == 0,
          let finalRef = ref.pointee
    else { return nil }
    
    self.ref = finalRef
  }
  
  deinit
  {
    git_reference_free(ref)
  }
  
  static func createSymbolic(name: String, repository: OpaquePointer,
                             target: String, log: String? = nil) -> GitReference?
  {
    let ref = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let result = git_reference_symbolic_create(ref, repository, name, target, 0,
                                               log ?? "")
    guard result == 0,
          let finalRef = ref.pointee
    else { return nil }
    
    return GitReference(reference: finalRef)
  }
  
  public var targetOID: OID?
  {
    guard let oid = git_reference_target(ref)
    else { return nil }
    
    return GitOID(oid: oid.pointee)
  }
  
  public var peeledTargetOID: OID?
  {
    guard let oid = git_reference_target_peel(ref)
    else { return nil }
    
    return GitOID(oid: oid.pointee)
  }
  
  public var symbolicTargetName: String?
  {
    guard let name = git_reference_symbolic_target(ref)
    else { return nil }
    
    return String(cString: name)
  }

  public var type: ReferenceType
  {
    return ReferenceType(rawValue: Int32(git_reference_type(ref).rawValue)) ??
           .invalid
  }
  
  public var name: String
  {
    guard let name = git_reference_name(ref)
    else { return "" }
    
    return String(cString: name)
  }
  
  public func resolve() -> Reference?
  {
    let ref = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let result = git_reference_resolve(ref, self.ref)
    guard result == 0,
          let finalRef = ref.pointee
    else { return nil }
    
    return GitReference(reference: finalRef)
  }
}
