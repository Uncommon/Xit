import Foundation

/// String-based commit for testing and placeholders
struct StringCommit: Commit
{
  typealias ObjectIdentifier = GitOID

  var parentOIDs: [GitOID]
  var message: String?
  var authorSig: Signature?
  var committerSig: Signature?
  var isSigned: Bool = false
  var id: GitOID
  var tree: StringTree? = nil

  func getTrailers() -> [(String, [String])] { [] }
}

public struct FakeCommit: Commit // same as NullTree
{
  public var parentOIDs: [GitOID]
  public var message: String?
  public var authorSig: Signature?
  public var committerSig: Signature?
  public var isSigned: Bool = false
  public var id: GitOID
  public var tree: FakeTree? = nil

  public func getTrailers() -> [(String, [String])] { [] }
  
  public init(parentOIDs: [GitOID], message: String? = nil,
              authorSig: Signature? = nil, committerSig: Signature? = nil,
              isSigned: Bool, id: GitOID, tree: FakeTree? = nil)
  {
    self.parentOIDs = parentOIDs
    self.message = message
    self.authorSig = authorSig
    self.committerSig = committerSig
    self.isSigned = isSigned
    self.id = id
    self.tree = tree
  }
}

/// String-based tree for testing and placeholders
public struct StringTree: Tree
{
  public var id: GitOID

  public var count: Int { entries.count }
  public var entries: [Entry] = []

  public func entry(named: String) -> Entry? { nil }
  public func entry(path: String) -> Entry? { nil }
  public func entry(at index: Int) -> Entry? { nil }
  
  public struct Entry: TreeEntry
  {
    public var id: GitOID { "" }
    public var type: GitObjectType { .invalid }
    public var name: String { "" }
    public var object: (any OIDObject)? { nil }
  }
}

public struct FakeTree: Tree
{
  public var count: Int { entries.count }
  public var id: GitOID
  public var entries: [Entry] = []
  
  public func entry(named: String) -> Entry? { nil }
  public func entry(path: String) -> Entry? { nil }
  public func entry(at index: Int) -> Entry? { nil }

  public struct Entry: TreeEntry
  {
    public typealias ObjectIdentifier = GitOID

    public var id: GitOID { .zero() }
    public var type: GitObjectType { .invalid }
    public var name: String { "" }
    public var object: (any OIDObject)? { nil }
  }
}

public struct FakeTag: Tag
{
  public let name: String
  public let signature: Signature?
  public let targetOID: GitOID?
  public let commit: FakeCommit?
  public let message: String?
  public let type: TagType
  public let isSigned: Bool
  
  public init(name: String, signature: Signature?, targetOID: GitOID?,
              commit: FakeCommit?, message: String?,
              type: TagType, isSigned: Bool)
  {
    self.name = name
    self.signature = signature
    self.targetOID = targetOID
    self.commit = commit
    self.message = message
    self.type = type
    self.isSigned = isSigned
  }
}
