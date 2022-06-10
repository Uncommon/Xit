import Foundation

/// String-based commit for testing and placeholders
struct StringCommit: Commit
{
  var parentOIDs: [any OID]
  var message: String?
  var authorSig: Signature?
  var committerSig: Signature?
  var isSigned: Bool = false
  var id: StringOID
  var tree: (any Tree)? = nil

  func getTrailers() -> [(String, [String])] { [] }
}

/// String-based tree for testing and placeholders
struct StringTree: Tree
{
  typealias ObjectIdentifier = StringOID
  
  var id: StringOID

  var count: Int { entries.count }
  var entries: [Entry] = []

  func entry(named: String) -> Entry? { nil }
  func entry(path: String) -> Entry? { nil }
  func entry(at index: Int) -> Entry? { nil }

  struct Entry: TreeEntry
  {
    typealias ObjectIdentifier = StringOID

    var id: StringOID { "" }
    var type: GitObjectType { .invalid }
    var name: String { "" }
    var object: (any OIDObject)? { nil }
  }
}
