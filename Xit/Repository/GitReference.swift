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
  /// Changes the ref to point to a different object
  func setTarget(_ newOID: OID, logMessage: String)
}

class GitReference: Reference
{
  private(set) var ref: OpaquePointer
  
  static func isValidName(_ name: String) -> Bool
  {
    return git_reference_is_valid_name(name) != 0
  }
  
  init(reference: OpaquePointer)
  {
    self.ref = reference
  }
  
  init?(name: String, repository: OpaquePointer)
  {
    var ref: OpaquePointer? = nil
    let result = git_reference_lookup(&ref, repository, name)
    guard result == 0,
          let finalRef = ref
    else { return nil }
    
    self.ref = finalRef
  }
  
  init?(headForRepo repo: OpaquePointer)
  {
    var ref: OpaquePointer? = nil
    let result = git_repository_head(&ref, repo)
    guard result == 0,
          let finalRef = ref
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
    var ref: OpaquePointer? = nil
    let result = git_reference_symbolic_create(&ref, repository, name, target, 0,
                                               log ?? "")
    guard result == 0,
          let finalRef = ref
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
    ReferenceType(rawValue: Int32(git_reference_type(ref).rawValue)) ?? .invalid
  }
  
  public var name: String
  {
    guard let name = git_reference_name(ref)
    else { return "" }
    
    return String(cString: name)
  }
  
  public func resolve() -> Reference?
  {
    var ref: OpaquePointer? = nil
    let result = git_reference_resolve(&ref, self.ref)
    guard result == 0,
          let finalRef = ref
    else { return nil }
    
    return GitReference(reference: finalRef)
  }
  
  public func setTarget(_ newOID: OID, logMessage: String)
  {
    guard var gitOID = (newOID as? GitOID)?.oid
    else { return }
    var newRef: OpaquePointer? = nil
    let result = git_reference_set_target(&newRef, ref, &gitOID, logMessage)
    guard result == 0,
          let finalRef = newRef
    else { return }
    
    ref = finalRef
  }
}
