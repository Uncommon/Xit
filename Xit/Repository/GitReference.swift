import Foundation

public protocol Reference
{
  associatedtype ID: OID

  /// For a direct reference, the target OID
  var targetOID: ID? { get }
  /// Peels a tag reference
  var peeledTargetOID: ID? { get }
  /// For a symbolic reference, the name of the target
  var symbolicTargetName: String? { get }
  /// Type of reference: oid (direct) or symbolic
  var type: ReferenceType { get }
  /// The reference name
  var name: String { get }
  
  /// Peels a symbolic reference until a direct reference is reached
  func resolve() -> Self?
  /// Changes the ref to point to a different object
  func setTarget(_ newOID: ID, logMessage: String)
}

public final class GitReference: Reference
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
  
  public var targetOID: GitOID?
  {
    guard let oid = git_reference_target(ref)
    else { return nil }
    
    return .init(oid: oid.pointee)
  }
  
  public var peeledTargetOID: GitOID?
  {
    guard let oid = git_reference_target_peel(ref)
    else { return nil }
    
    return .init(oid: oid.pointee)
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
  
  public func resolve() -> GitReference?
  {
    guard let ref = try? OpaquePointer.from({
      git_reference_resolve(&$0, self.ref)
    })
    else { return nil }
    
    return GitReference(reference: ref)
  }
  
  public func setTarget(_ newOID: GitOID, logMessage: String)
  {
    var gitOID = newOID.oid
    guard let newRef = try? OpaquePointer.from({
      git_reference_set_target(&$0, ref, &gitOID, logMessage)
    })
    else { return }
    
    ref = newRef
  }
}
