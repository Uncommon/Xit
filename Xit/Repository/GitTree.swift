import Foundation

public protocol Tree: OIDObject
{
  var count: Int { get }
  
  func entry(named: String) -> (any TreeEntry)?
  func entry(path: String) -> (any TreeEntry)?
  func entry(at index: Int) -> (any TreeEntry)?
}

public protocol TreeEntry: OIDObject
{
  var type: GitObjectType { get }
  var name: String { get }
  var object: (any OIDObject)? { get }
}


/// Used as a return value when an entry can't be returned for a given subscript
struct NullEntry: TreeEntry
{
  var id: any OID
  { GitOID.zero() }
  var type: GitObjectType
  { .invalid }
  var name: String
  { "" }
  var object: (any OIDObject)?
  { nil }
}

final class GitTree: Tree
{
  struct EntryCollection: Collection
  {
    let tree: GitTree

    var startIndex: Int { 0 }
    var endIndex: Int { tree.count }
    
    func index(after i: Int) -> Int
    {
      return i + 1
    }
    
    subscript(position: Int) -> any TreeEntry
    {
      guard let result = git_tree_entry_byindex(tree.tree, position),
            let owner = git_tree_owner(tree.tree)
      else {
        return NullEntry()
      }
      
      return GitTreeEntry(entry: result, owner: owner)
    }
  }
  
  var entries: EntryCollection
  { EntryCollection(tree: self) }
  
  let tree: OpaquePointer
  
  var id: any OID
  {
    guard let result = git_tree_id(tree)
    else { return GitOID.zero() }
    
    return GitOID(oidPtr: result)
  }
  
  var count: Int
  { git_tree_entrycount(tree) }
  
  init(tree: OpaquePointer)
  {
    self.tree = tree
  }
  
  init?(oid: git_oid, repo: OpaquePointer)
  {
    var oid = oid // needs to be mutable
    guard let tree = try? OpaquePointer.from({
      git_object_lookup(&$0, repo, &oid, GIT_OBJECT_TREE)
    })
    else { return nil }
    
    self.tree = tree
  }
  
  deinit
  {
    git_tree_free(tree)
  }
  
  func entry(named name: String) -> (any TreeEntry)?
  {
    guard let result = git_tree_entry_byname(tree, name),
          let owner = git_tree_owner(tree)
    else { return nil }
    
    return GitTreeEntry(entry: result, owner: owner)
  }
  
  func entry(path: String) -> (any TreeEntry)?
  {
    guard let owner = git_tree_owner(tree),
          let entry = try? OpaquePointer.from({
            git_tree_entry_bypath(&$0, tree, path)
          })
    else { return nil }
    
    return GitTreeEntry(entry: entry, owner: owner)
  }
  
  func entry(at index: Int) -> (any TreeEntry)?
  {
    switch index {
      case 0..<count:
        return entries[index]
      default:
        return nil
    }
  }
}

class GitTreeEntry: TreeEntry
{
  let entry: OpaquePointer
  let owner: OpaquePointer
  
  var id: any OID
  {
    guard let gitOID = git_tree_entry_id(entry)
    else { return GitOID.zero() }
    
    return GitOID(oidPtr: gitOID)
  }
  
  var type: GitObjectType
  {
    let result = git_tree_entry_type(entry)
    
    return GitObjectType(rawValue: result.rawValue) ?? .invalid
  }
  
  var name: String
  {
    let name = git_tree_entry_name(entry)
    
    return name.map { String(cString: $0) } ?? ""
  }
  
  var object: (any OIDObject)?
  {
    guard let gitObject = try? OpaquePointer.from({
      git_tree_entry_to_object(&$0, owner, entry)
    })
    else { return nil }
    
    switch type {
      case .blob:
        return GitBlob(blob: gitObject)
      case .tree:
        return GitTree(tree: gitObject)
      default:
        return nil
    }
  }
  
  init(entry: OpaquePointer, owner: OpaquePointer)
  {
    self.entry = entry
    self.owner = owner
  }

  deinit
  {
    git_tree_entry_free(entry)
  }
}
