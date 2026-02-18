import Foundation
import Clibgit2

public protocol Reference
{
  /// For a direct reference, the target OID
  var targetOID: GitOID? { get }
  /// Peels a tag reference
  var peeledTargetOID: GitOID? { get }
  /// For a symbolic reference, the name of the target
  var symbolicTargetName: (any ReferenceName)? { get }
  /// Type of reference: oid (direct) or symbolic
  var type: ReferenceType { get }
  /// The reference name
  var name: any ReferenceName { get }

  /// Peels a symbolic reference until a direct reference is reached
  func resolve() -> Self?
  /// Changes the ref to point to a different object
  func setTarget(_ newOID: GitOID, logMessage: String)
}

final public class GitReference: Reference
{
  private(set) var ref: OpaquePointer
  
  public static func isValidName(_ name: String) -> Bool
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

  private func specificRefName(_ name: String) -> (any ReferenceName)?
  {
    guard let general = GeneralRefName(rawValue: name)
    else { return nil }

    return
        LocalBranchRefName(general) ??
        RemoteBranchRefName(general) ??
        TagRefName(general) ??
        general
  }

  public var symbolicTargetName: (any ReferenceName)?
  {
    guard let cName = git_reference_symbolic_target(ref)
    else { return nil }
    let name = String(cString: cName)

    return specificRefName(name)
  }

  public var type: ReferenceType
  {
    ReferenceType(rawValue: Int32(git_reference_type(ref).rawValue)) ?? .invalid
  }
  
  public var name: any ReferenceName
  {
    guard let cName = git_reference_name(ref)
    else {
      assertionFailure("can't get reference name")
      return GeneralRefName(unchecked: "")
    }
    let name = String(cString: cName)

    return specificRefName(name) ?? {
      assertionFailure("reference name is invalid")
      return GeneralRefName(unchecked: name)
    }()
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
