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
  var id: StringOID

  var count: Int { entries.count }
  var entries: [any TreeEntry] = []

  func entry(named: String) -> (any TreeEntry)? { nil }
  func entry(path: String) -> (any TreeEntry)? { nil }
  func entry(at index: Int) -> (any TreeEntry)? { nil }

  struct Entry: TreeEntry
  {
    typealias ObjectIdentifier = String

    var id: StringOID { "" }
    var type: GitObjectType { .invalid }
    var name: String { "" }
    var object: (any OIDObject)? { nil }
  }
}
