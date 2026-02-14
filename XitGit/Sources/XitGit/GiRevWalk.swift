import Foundation
import Clibgit2
import FakedMacro

@Faked
public protocol RevWalk: AnyObject, Sequence, IteratorProtocol
  where Element == GitOID
{
  func reset()
  func setSorting(_ sort: RevWalkSorting)
  func push(oid: GitOID)
  func next() -> GitOID?
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

public final class GitRevWalk: RevWalk
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
  
  public func push(oid: GitOID)
  {
    _ = oid.withUnsafeOID { git_revwalk_push(walker, $0) }
  }
  
  public func next() -> GitOID?
  {
    var oid = git_oid()
    let result = git_revwalk_next(&oid, walker)
    guard result == 0
    else { return nil }
    
    return GitOID(oid: oid)
  }
}
