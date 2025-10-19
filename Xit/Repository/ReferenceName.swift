import Foundation
import FakedMacro

public protocol ReferenceKind
{
  /// The prefix that all references of this type must have
  static var prefix: String { get }
}

public protocol BranchReferenceKind: ReferenceKind
{
  /// The portion of the full path to drop to create the tracking branch name
  static var dropTrackingPrefix: String { get }
}

public struct LocalBranchReference: BranchReferenceKind
{
  public static var prefix: String { RefPrefixes.heads }
  public static var dropTrackingPrefix: String { "" }
}

public struct RemoteReference: ReferenceKind
{
  public static var prefix: String { RefPrefixes.remotes }
}

public struct RemoteBranchReference: BranchReferenceKind
{
  public static var prefix: String { RefPrefixes.remotes }
  public static var dropTrackingPrefix: String { RefPrefixes.remotes }
}

public struct TagReference: ReferenceKind
{
  public static var prefix: String { RefPrefixes.tags }
}

/// A type that wraps a full reference name for a specific kind of reference:
/// branch, tag, etc.
///
/// This addresses the issue of, for example, having a "branch" parameter
/// that is a plain string, and it is not obvious if it should be the full
/// reference name or just the branch name with no "refs/heads/" prefix.
///
/// As a `RawRepresentable` type, the raw value is the full path.
public protocol ReferenceName: Fakable, PathTreeData,
                               Sendable, Equatable, RawRepresentable
  where RawValue == String
{
  // TODO: Maybe remove from protocol since GeneralRefName doesn't need it
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
  public var treeNodePath: String { fullPath }
}

public struct GeneralRefName: ReferenceName, Hashable
{
  public let rawValue: String

  public var fullPath: String { rawValue }
  public var name: String { rawValue.lastPathComponent } // probably not used

  public static func fakeDefault() -> GeneralRefName { .init(unchecked: "fake") }

  public init?(rawValue: String)
  {
    guard GitReference.isValidName(rawValue)
    else { return nil }

    self.rawValue = rawValue
  }

  public init(_ refName: some ReferenceName)
  {
    self.rawValue = refName.rawValue
  }

  /// Use when the name is statically known to be valid, or when an instance must
  /// exist but there is no valid value due to unexpected circumstances.
  init(unchecked: String)
  {
    self.rawValue = unchecked
  }
}

extension ReferenceName where Self == GeneralRefName
{
  static var head: GeneralRefName { .init(unchecked: "HEAD") }
}

public struct PrefixedRefName<Kind>: ReferenceName, Hashable
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

  public init?(_ refName: GeneralRefName)
  {
    let fullPath = refName.fullPath
    guard fullPath.hasPrefix(Kind.prefix)
    else { return nil }

    self.name = fullPath.droppingPrefix(Kind.prefix)
  }

  // Originally, the intent was to have init(_:) be checked, and
  // init(stringLiteral:) be unchecked. But because of SE-0213 the compiler
  // always prefers the stringLiteral version.
  static func named(_ name: String) -> Self?
  {
    // +/ (appending path component) will quietly consume leading slashes
    guard !name.hasPrefix("/") && GitReference.isValidName(Kind.prefix +/ name)
    else { return nil }

    return .init(rawValue: Kind.prefix +/ name)
  }
}

extension PrefixedRefName where Kind: BranchReferenceKind
{
  /// The path to use as a remote tracking branch
  var trackingPath: String { fullPath.droppingPrefix(Kind.dropTrackingPrefix) }
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

    self.init(rawValue: Kind.prefix +/ remote +/ branch)
  }
}

extension PrefixedRefName: ExpressibleByStringLiteral,
                           ExpressibleByStringInterpolation
{
  public init(stringLiteral: StringLiteralType)
  {
    self.init(rawValue: Kind.prefix +/ stringLiteral)!
  }
}

public typealias LocalBranchRefName = PrefixedRefName<LocalBranchReference>
public typealias RemoteBranchRefName = PrefixedRefName<RemoteBranchReference>
public typealias TagRefName = PrefixedRefName<TagReference>

extension PrefixedRefName: Fakable
{ public static func fakeDefault() -> Self { .named("fake")! } }
