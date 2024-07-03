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

struct FakeCommit: Commit // same as NullTree
{
  var parentOIDs: [GitOID]
  var message: String?
  var authorSig: Signature?
  var committerSig: Signature?
  var isSigned: Bool = false
  var id: GitOID
  var tree: FakeTree? = nil

  func getTrailers() -> [(String, [String])] { [] }
}

/// String-based tree for testing and placeholders
struct StringTree: Tree
{
  var id: GitOID

  var count: Int { entries.count }
  var entries: [Entry] = []

  func entry(named: String) -> Entry? { nil }
  func entry(path: String) -> Entry? { nil }
  func entry(at index: Int) -> Entry? { nil }

  struct Entry: TreeEntry
  {
    var id: GitOID { "" }
    var type: GitObjectType { .invalid }
    var name: String { "" }
    var object: (any OIDObject)? { nil }
  }
}

struct FakeTree: Tree
{
  var count: Int { entries.count }
  var id: GitOID
  var entries: [Entry] = []

  func entry(named: String) -> Entry? { nil }
  func entry(path: String) -> Entry? { nil }
  func entry(at index: Int) -> Entry? { nil }

  struct Entry: TreeEntry
  {
    typealias ObjectIdentifier = GitOID

    var id: GitOID { .zero() }
    var type: GitObjectType { .invalid }
    var name: String { "" }
    var object: (any OIDObject)? { nil }
  }
}

struct FakeTag: Tag
{
  let name: String
  let signature: Signature?
  let targetOID: GitOID?
  let commit: FakeCommit?
  let message: String?
  let type: TagType
  let isSigned: Bool
}
