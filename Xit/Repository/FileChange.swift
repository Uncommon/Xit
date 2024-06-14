import Foundation

public struct FileChange: Sendable
{
  var oid: (any OID)?
  var path: String
  var oldPath: String
  var status: DeltaStatus

  /// Repository-relative path to use for git operations
  var gitPath: String
  { path.droppingPrefix("\(WorkspaceTreeBuilder.rootName)/") }

  init(path: String, oldPath: String = "",
       oid: (any OID)? = nil, change: DeltaStatus = .unmodified)
  {
    self.path = path
    self.oldPath = oldPath
    self.status = change
  }
}

extension FileChange: Equatable
{
  public static func == (lhs: FileChange, rhs: FileChange) -> Bool
  {
    lhs.path == rhs.path &&
    lhs.status == rhs.status &&
    lhs.oldPath == rhs.oldPath &&
    (lhs.oid?.equals(rhs.oid) ?? (rhs.oid == nil))
  }
}

extension FileChange: Comparable
{
  public static func < (lhs: FileChange, rhs: FileChange) -> Bool
  {
    lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
  }
}

extension FileChange: CustomStringConvertible
{
  public var description: String
  { "\(path) [\(status.description)]" }
}
