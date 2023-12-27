import Foundation

public protocol ReferenceKind
{
  /// The prefix that all references of this type must have
  static var prefix: String { get }
}

public struct LocalBranchReference: ReferenceKind
{ public static var prefix: String { RefPrefixes.heads } }

public struct RemoteReference: ReferenceKind
{ public static var prefix: String { RefPrefixes.remotes } }

public struct RemoteBranchReference: ReferenceKind
{ public static var prefix: String { RefPrefixes.remotes } }

public struct TagReference: ReferenceKind
{ public static var prefix: String { RefPrefixes.tags} }

/// A type that wraps a full reference name for a specific kind of reference.
///
/// This addresses the issue of, for example, having a "branch" parameter
/// that is a plain string, and it is not obvious if it should be the full
/// reference name or just the branch name with no "refs/heads/" prefix.
public struct ReferenceName<T>: RawRepresentable where T: ReferenceKind
{
  /// The simple name, with no prefix.
  public let name: String
  /// The fully qualified reference name.
  public var rawValue: String { T.prefix +/ name }
  
  static func validate(name: String) -> Bool
  {
    GitReference.isValidName(name)
  }
  
  public init?(rawValue: String)
  {
    guard GitReference.isValidName(rawValue) &&
          rawValue.hasPrefix(T.prefix)
    else { return nil }

    self.name = rawValue.droppingPrefix(T.prefix)
  }
  
  public init?(_ name: String)
  {
    // +/ (appending path componens) will quietly consume leading slashes
    guard !name.hasPrefix("/") && GitReference.isValidName(T.prefix +/ name)
    else { return nil }
    
    self.name = name
  }
}

extension ReferenceName where T == RemoteBranchReference
{
  var remoteName: String
  { name.components(separatedBy: "/").first ?? "" }
  var branchName: String
  {
    guard let slashIndex = name.firstIndex(of: "/")
    else { return "" }
    let index = name.index(slashIndex, offsetBy: 1)

    return String(name[index...])
  }
  
  static func validate(name: String) -> Bool
  {
    GitReference.isValidName(name) &&
    name.components(separatedBy: "/").count > 1
  }
  
  init?(remote: String, branch: String)
  {
    guard !remote.hasPrefix("/") && !branch.hasPrefix("/")
    else { return nil }
    
    self.init(remote +/ branch)
  }
}

public typealias LocalBranchRefName = ReferenceName<LocalBranchReference>
public typealias RemoteBranchRefName = ReferenceName<RemoteBranchReference>
public typealias TagRefName = ReferenceName<TagReference>
