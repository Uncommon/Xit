import Foundation
import FakedMacro

public protocol ReferenceKind
{
  /// The prefix that all references of this type must have
  static var prefix: String { get }
}

public struct LocalBranchReference: ReferenceKind
{
  public static var prefix: String { RefPrefixes.heads }
}

public struct RemoteReference: ReferenceKind
{
  public static var prefix: String { RefPrefixes.remotes }
}

public struct RemoteBranchReference: ReferenceKind
{
  public static var prefix: String { RefPrefixes.remotes }
}

public struct TagReference: ReferenceKind
{
  public static var prefix: String { RefPrefixes.tags}
}

/// A type that wraps a full reference name for a specific kind of reference:
/// branch, tag, etc.
///
/// This addresses the issue of, for example, having a "branch" parameter
/// that is a plain string, and it is not obvious if it should be the full
/// reference name or just the branch name with no "refs/heads/" prefix.
///
/// As a `RawRepresentable` type, the raw value is the full path.
public protocol ReferenceName: Fakable, RawRepresentable where RawValue == String
{
  /// The main name, with no prefix.
  ///
  /// "refs/heads/branch" → "branch"
  /// "refs/remotes/origin/branch" → "origin/branch"
  var name: String { get }

  /// The name without prefix or other parent elements such as remote name.
  ///
  /// "refs/heads/branch" → "branch"
  /// "refs/remotes/origin/branch" → "branch"
  var localName: String { get }
  
  /// The fully qualified reference name.
  var fullPath: String { get }
}

extension ReferenceName
{
  public var localName: String { name }
  public var rawValue: String { fullPath }
}

public struct PrefixedRefName<Kind>: ReferenceName, Equatable
  where Kind: ReferenceKind
{
  public let name: String
  public var fullPath: String { Kind.prefix +/ name }

  var isValid: Bool
  {
    Self.validate(name: rawValue)
  }

  static func validate(name: String) -> Bool
  {
    GitReference.isValidName(name)
  }
  
  public init?(rawValue: String)
  {
    guard GitReference.isValidName(rawValue) &&
          rawValue.hasPrefix(Kind.prefix)
    else { return nil }

    self.name = rawValue.droppingPrefix(Kind.prefix)
  }
  
  public init?(_ name: String)
  {
    // +/ (appending path component) will quietly consume leading slashes
    guard !name.hasPrefix("/") && GitReference.isValidName(Kind.prefix +/ name)
    else { return nil }
    
    self.name = name.droppingPrefix(Kind.prefix)
  }
}

extension PrefixedRefName where Kind == RemoteBranchReference
{
  var remoteName: String
  { String(name.split(maxSplits: 1) { $0 == "/" }.first ?? "") }

  var localName: String
  {
    guard let slashIndex = name.firstIndex(of: "/")
    else {
      assertionFailure("remote branch ref parse failure")
      return ""
    }
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

public typealias LocalBranchRefName = PrefixedRefName<LocalBranchReference>
public typealias RemoteBranchRefName = PrefixedRefName<RemoteBranchReference>
public typealias TagRefName = PrefixedRefName<TagReference>

extension PrefixedRefName: Fakable
{ public static func fakeDefault() -> Self { .init("fake")! } }
