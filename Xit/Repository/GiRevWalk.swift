import Foundation

// It would be nice to say this conforms to Sequence and IteratorProtocol,
// but then it could only be used as a generic constraint.
public protocol RevWalk
{
  func reset()
  func setSorting(_ sort: RevWalkSorting)
  func push(oid: OID)
  func next() -> OID?
}

public struct RevWalkSorting: OptionSet
{
  public var rawValue: git_sort_t.RawValue
  
  // Explicitly implemented to make it public, conforming to RawRepresentable
  public init(rawValue: git_sort_t.RawValue)
  {
    self.rawValue = rawValue
  }
  
  public init(sort: git_sort_t)
  {
    self.rawValue = sort.rawValue
  }
  
  public static let topological = RevWalkSorting(sort: GIT_SORT_TOPOLOGICAL)
  public static let time = RevWalkSorting(sort: GIT_SORT_TIME)
  public static let reverse = RevWalkSorting(sort: GIT_SORT_REVERSE)
}

class GitRevWalk: RevWalk
{
  let walker: OpaquePointer
  
  init?(repository: OpaquePointer)
  {
    let revWalk = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let result = git_revwalk_new(revWalk, repository)
    guard result == 0,
          let finalRevWalk = revWalk.pointee
    else { return nil }
    
    self.walker = finalRevWalk
  }
  
  deinit
  {
    git_revwalk_free(walker)
  }
  
  public func reset()
  {
    git_revwalk_reset(walker)
  }
  
  public func setSorting(_ sort: RevWalkSorting)
  {
    git_revwalk_sorting(walker, sort.rawValue)
  }
  
  public func push(oid: OID)
  {
    guard let gitOID = oid as? GitOID
    else { return }
    
    git_revwalk_push(walker, gitOID.unsafeOID())
  }
  
  public func next() -> OID?
  {
    let oid = UnsafeMutablePointer<git_oid>.allocate(capacity: 1)
    let result = git_revwalk_next(oid, walker)
    guard result == 0
    else { return nil }
    
    return GitOID(oid: oid.pointee)
  }
}
