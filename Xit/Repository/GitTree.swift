import Foundation
import FakedMacro

public protocol Tree: OIDObject
{
  associatedtype Entry: TreeEntry
  associatedtype EntryCollection: Collection<Entry>

  /// Number of entries in the tree.
  var count: Int { get }

  /// The tree's direct children.
  var entries: EntryCollection { get }

  /// Finds an entry with the given name.
  func entry(named: String) -> Entry?
  /// Finds a descendent item matching a relative path.
  func entry(path: String) -> Entry?
  /// Finds an entry by index.
  func entry(at index: Int) -> Entry?
}

@Faked(inherit: ["EmptyOIDObject"])
public protocol TreeEntry: OIDObject
{
  var type: GitObjectType { get }
  var name: String { get }
  /// The object referenced by the entry is not a specific type because it
  /// could be a blob or a sub-tree.
  var object: (any OIDObject)? { get }
}

extension GitObjectType: Fakable
{
  public static func fakeDefault() -> Self { .invalid }
}

public final class GitTree: Tree
{
  public struct EntryCollection: Collection
  {
    let tree: GitTree

    public var startIndex: Int { 0 }
    public var endIndex: Int { tree.count }

    public func index(after i: Int) -> Int
    {
      return i + 1
    }
    
    public subscript(position: Int) -> GitTreeEntry
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
  
  public var entries: EntryCollection
  { .init(tree: self) }
  
  let tree: OpaquePointer
  
  public var id: GitOID
  {
    guard let result = git_tree_id(tree)
    else { return .zero() }
    
    return .init(oidPtr: result)
  }
  
  public var count: Int
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
  
  public func entry(named name: String) -> GitTreeEntry?
  {
    guard let result = git_tree_entry_byname(tree, name),
          let owner = git_tree_owner(tree)
    else { return nil }
    
    return GitTreeEntry(entry: result, owner: owner, owned: false)
  }
  
  public func entry(path: String) -> GitTreeEntry?
  {
    guard let owner = git_tree_owner(tree),
          let entry = try? OpaquePointer.from({
            git_tree_entry_bypath(&$0, tree, path)
          })
    else { return nil }
    
    return GitTreeEntry(entry: entry, owner: owner, owned: true)
  }
  
  public func entry(at index: Int) -> GitTreeEntry?
  {
    switch index {
      case 0..<count:
        return entries[index]
      default:
        return nil
    }
  }
}

public final class GitTreeEntry: TreeEntry
{
  let entry: OpaquePointer!
  let owner: OpaquePointer!
  let owned: Bool

  static var invalid: Self { .init() }

  public var id: GitOID
  {
    guard let gitOID = git_tree_entry_id(entry)
    else { return .zero() }
    
    return .init(oidPtr: gitOID)
  }
  
  public var type: GitObjectType
  {
    let result = git_tree_entry_type(entry)
    
    return GitObjectType(rawValue: result.rawValue) ?? .invalid
  }
  
  public var name: String
  {
    let name = git_tree_entry_name(entry)
    
    return name.map { String(cString: $0) } ?? ""
  }
  
  public var object: (any OIDObject)?
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
