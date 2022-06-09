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
    
    subscript(position: Int) -> GitTreeEntry
    {
      guard let result = git_tree_entry_byindex(tree.tree, position),
            let owner = git_tree_owner(tree.tree)
      else {
        assertionFailure("can't get tree entry")
        return .invalid
      }
      
      return .init(entry: result, owner: owner, owned: false)
    }
  }
  
  var entries: EntryCollection
  { .init(tree: self) }
  
  let tree: OpaquePointer
  
  var id: GitOID
  {
    guard let result = git_tree_id(tree)
    else { return .zero() }
    
    return .init(oidPtr: result)
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
    
    return GitTreeEntry(entry: result, owner: owner, owned: false)
  }
  
  func entry(path: String) -> (any TreeEntry)?
  {
    guard let owner = git_tree_owner(tree),
          let entry = try? OpaquePointer.from({
            git_tree_entry_bypath(&$0, tree, path)
          })
    else { return nil }
    
    return GitTreeEntry(entry: entry, owner: owner, owned: true)
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

final class GitTreeEntry: TreeEntry
{
  let entry: OpaquePointer!
  let owner: OpaquePointer!
  let owned: Bool

  static var invalid: Self { .init() }

  var id: GitOID
  {
    guard let gitOID = git_tree_entry_id(entry)
    else { return .zero() }
    
    return .init(oidPtr: gitOID)
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
  
  init(entry: OpaquePointer, owner: OpaquePointer, owned: Bool)
  {
    self.entry = entry
    self.owner = owner
    self.owned = owned
  }

  deinit
  {
    if owned {
      git_tree_entry_free(entry)
    }
  }

  private init()
  {
    self.entry = nil
    self.owner = nil
    self.owned = false
  }
}
