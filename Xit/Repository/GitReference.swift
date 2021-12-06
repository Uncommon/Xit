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

final class GitReference: Reference
{
  private(set) var ref: OpaquePointer
  
  static func isValidName(_ name: String) -> Bool
  {
    var valid: Int32 = 0

    return git_reference_name_is_valid(&valid, name) == 0 && valid != 0
  }
  
  init(reference: OpaquePointer)
  {
    self.ref = reference
  }
  
  init?(name: String, repository: OpaquePointer)
  {
    guard let ref = try? OpaquePointer.from({
      git_reference_lookup(&$0, repository, name)
    })
    else { return nil }
    
    self.ref = ref
  }
  
  init?(headForRepo repo: OpaquePointer)
  {
    guard let ref = try? OpaquePointer.from({
      git_repository_head(&$0, repo)
    })
    else { return nil }
    
    self.ref = ref
  }
  
  deinit
  {
    git_reference_free(ref)
  }
  
  static func createSymbolic(name: String, repository: OpaquePointer,
                             target: String, log: String? = nil) -> GitReference?
  {
    guard let ref = try? OpaquePointer.from({
      git_reference_symbolic_create(&$0, repository, name, target, 0, log ?? "")
    })
    else { return nil }
    
    return GitReference(reference: ref)
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
    guard let ref = try? OpaquePointer.from({
      git_reference_resolve(&$0, self.ref)
    })
    else { return nil }
    
    return GitReference(reference: ref)
  }
  
  public func setTarget(_ newOID: OID, logMessage: String)
  {
    guard var gitOID = (newOID as? GitOID)?.oid,
          let newRef = try? OpaquePointer.from({
            git_reference_set_target(&$0, ref, &gitOID, logMessage)
          })
    else { return }
    
    ref = newRef
  }
}
