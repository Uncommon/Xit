import Foundation

// It would be nice to say this conforms to Sequence and IteratorProtocol,
// but then it could only be used as a generic constraint.
public protocol RevWalk
{
  func reset()
  func setSorting(_ sort: RevWalkSorting)
  func push(oid: any OID)
  func next() -> (any OID)?
}

public struct RevWalkSorting: OptionSet, Sendable
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

final class GitRevWalk: RevWalk
{
  let walker: OpaquePointer
  
  init?(repository: OpaquePointer)
  {
    guard let revWalk = try? OpaquePointer.from({
      git_revwalk_new(&$0, repository)
    })
    else { return nil }
    
    self.walker = revWalk
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
  
  public func push(oid: any OID)
  {
    guard let gitOID = oid as? GitOID
    else { return }
    
    _ = gitOID.withUnsafeOID { git_revwalk_push(walker, $0) }
  }
  
  public func next() -> (any OID)?
  {
    var oid = git_oid()
    let result = git_revwalk_next(&oid, walker)
    guard result == 0
    else { return nil }
    
    return GitOID(oid: oid)
  }
}
