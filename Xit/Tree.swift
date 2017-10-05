import Foundation

protocol Tree: OIDObject
{
  var count: Int { get }
  
  func entry(named: String) -> TreeEntry?
  func entry(path: String) -> TreeEntry?
}

protocol TreeEntry: OIDObject
{
  var type: GTObjectType { get }
  var name: String { get }
  var object: OIDObject? { get }
}

class GitTree: Tree
{
  let tree: OpaquePointer
  
  var oid: OID
  {
    guard let result = git_tree_id(tree)
    else { return GitOID.zero() }
    
    return GitOID(oidPtr: result)
  }
  
  var count: Int
  {
    return git_index_entrycount(tree)
  }
  
  init(tree: OpaquePointer)
  {
    self.tree = tree
  }
  
  deinit
  {
    git_tree_free(tree)
  }
  
  func entry(named name: String) -> TreeEntry?
  {
    guard let result = git_tree_entry_byname(tree, name),
          let owner = git_tree_owner(tree)
    else { return nil }
    
    return GitTreeEntry(entry: result, owner: owner)
  }
  
  func entry(path: String) -> TreeEntry?
  {
    guard let owner = git_tree_owner(tree)
    else { return nil }
    var entry: OpaquePointer?
    let result = git_tree_entry_bypath(&entry, tree, path)
    guard result == 0,
          let finalEntry = entry
    else { return nil }
    
    return GitTreeEntry(entry: finalEntry, owner: owner)
  }
}

class GitTreeEntry: TreeEntry
{
  let entry: OpaquePointer
  let owner: OpaquePointer
  
  var oid: OID
  {
    guard let gitOID = git_tree_entry_id(entry)
    else { return GitOID.zero() }
    
    return GitOID(oidPtr: gitOID)
  }
  
  var type: GTObjectType
  {
    let result = git_tree_entry_type(entry)
    
    return GTObjectType(rawValue: result.rawValue) ?? .bad
  }
  
  var name: String
  {
    let name = git_tree_entry_name(entry)
    
    return name.map({ String(cString: $0) }) ?? ""
  }
  
  var object: OIDObject?
  {
    var gitObject: OpaquePointer?
    let result = git_tree_entry_to_object(&gitObject, owner, entry)
    guard result == 0,
          let finalObject = gitObject
    else { return nil }
    
    switch type {
      case .commit:
        return XTCommit(gitCommit: finalObject, repository: owner)
      case .tree:
        return GitTree(tree: finalObject)
      default:
        return nil
    }
  }
  
  init(entry: OpaquePointer, owner: OpaquePointer)
  {
    self.entry = entry
    self.owner = owner
  }
}
