import Foundation

public struct FileChange: Sendable
{
  public var oid: GitOID?
  public var path: String
  public var oldPath: String
  public var status: DeltaStatus

  /// Repository-relative path to use for git operations
  public var gitPath: String
  { path.droppingPrefix("\(FileChangeNode.rootName)/") }

  public init(path: String, oldPath: String = "",
              oid: GitOID? = nil, change: DeltaStatus = .unmodified)
  {
    self.path = path
    self.oldPath = oldPath
    self.status = change
    self.oid = oid
  }
}

extension FileChange: Equatable
{
  public static func == (lhs: FileChange, rhs: FileChange) -> Bool
  {
    lhs.path == rhs.path &&
    lhs.status == rhs.status &&
    lhs.oldPath == rhs.oldPath &&
    lhs.oid == rhs.oid
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

extension FileChange: Hashable
{
  public func hash(into hasher: inout Hasher)
  {
    hasher.combine(path)
    hasher.combine(status)
    hasher.combine(oldPath)
    hasher.combine(oid ?? .zero())
  }
}
