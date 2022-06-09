import Foundation

/// A staging index for creating a commit.
public protocol StagingIndex
{
  /// Reloads the index from the disk.
  func refresh() throws
  /// Saves the index to the disk.
  func save() throws
  /// Adds a local file to the index
  func add(path: String) throws
  /// Adds or updates a file with the given data
  func add(data: any ContiguousBytes, count: Int, path: String) throws
  /// Reads the tree into the index
  func read(tree: any Tree) throws
  /// Removes a file from the index
  func remove(path: String) throws
  /// Removes all files
  func clear() throws
  
  /// Returns the total numbef of entries in the index.
  var entryCount: Int { get }
  /// Returns the entry at the given index in the list of entries.
  func entry(atIndex: Int) -> (any IndexEntry)!
  /// Returns the entry matching the given file path.
  func entry(at path: String) -> (any IndexEntry)?
  
  /// Returns true if any entry is conflicted.
  var hasConflicts: Bool { get }
  /// Iterates through the conflicted entries.
  var conflicts: AnySequence<ConflictEntry> { get }

  /// Creates a tree object from the index contents, and writes it to the
  /// repository so it can be referenced by a commit.
  func writeTree() throws -> any Tree
}

extension StagingIndex
{
  /// A collection for accessing or iterating through index entries.
  var entries: EntryCollection
  { EntryCollection(index: self) }

  func add(data: Data, path: String) throws
  {
    try add(data: data, count: data.count, path: path)
  }
}

class EntryCollection: RandomAccessCollection
{
  let index: StagingIndex
  
  var startIndex: Int { 0 }
  
  var endIndex: Int
  { index.entryCount }
  
  init(index: StagingIndex)
  {
    self.index = index
  }

  subscript(position: Int) -> any IndexEntry
  {
    return index.entry(atIndex: position)
  }
}

/// An individual file entry in an index.
public protocol IndexEntry
{
  var oid: any OID { get }
  var path: String { get }
  var conflicted: Bool { get }
}

public protocol ConflictEntry
{
  var ancestor: any IndexEntry { get }
  var ours: any IndexEntry { get }
  var theirs: any IndexEntry { get }
}

/// Staging index implemented with libgit2
class GitIndex: StagingIndex
{
  let index: OpaquePointer

  var entryCount: Int
  { git_index_entrycount(index) }
  
  var hasConflicts: Bool
  { git_index_has_conflicts(index) != 0 }
  
  var conflicts: AnySequence<any Xit.ConflictEntry>
  { AnySequence { ConflictIterator(index: self.index) } }

  init?(repository: OpaquePointer)
  {
    guard let index = try? OpaquePointer.from({
      git_repository_index(&$0, repository)
    })
    else { return nil }
    
    git_index_read(index, 1)
    self.index = index
  }
  
  func entry(atIndex index: Int) -> (any IndexEntry)!
  {
    switch index {
      case 0..<entryCount:
        guard let gitEntry = git_index_get_byindex(self.index, index)
        else { return nil }
        
        return Entry(gitEntry: gitEntry.pointee)
      default:
        return nil
    }
  }
  
  func entry(at path: String) -> (any IndexEntry)?
  {
    var position: Int = 0
    guard git_index_find(&position, index, path) == 0,
          let entry = git_index_get_byindex(index, position)
    else { return nil }
    
    return Entry(gitEntry: entry.pointee)
  }
  
  func refresh() throws
  {
    try RepoError.throwIfGitError(git_index_read(index, 1))
  }
  
  func save() throws
  {
    try RepoError.throwIfGitError(git_index_write(index))
  }
  
  func read(tree: any Tree) throws
  {
    guard let gitTree = tree as? GitTree
    else { throw RepoError.unexpected }
    
    try RepoError.throwIfGitError(git_index_read_tree(index, gitTree.tree))
  }
  
  func add(path: String) throws
  {
    try RepoError.throwIfGitError(git_index_add_bypath(index, path))
  }
  
  func add(data: ContiguousBytes, count: Int, path: String) throws
  {
    let result = data.withUnsafeBytes {
      (bytes: UnsafeRawBufferPointer) -> Int32 in
      var entry = git_index_entry()
      
      return path.withCString {
        (path) in
        entry.path = path
        entry.mode = GIT_FILEMODE_BLOB.rawValue
        return git_index_add_frombuffer(index, &entry,
                                        bytes.baseAddress, count)
      }
    }
    
    try RepoError.throwIfGitError(result)
  }

  func remove(path: String) throws
  {
    try RepoError.throwIfGitError(git_index_remove_bypath(index, path))
  }
  
  func clear() throws
  {
    try RepoError.throwIfGitError(git_index_clear(index))
  }
  
  func writeTree() throws -> any Tree
  {
    var treeOID = git_oid()
    let result = git_index_write_tree(&treeOID, index)
    
    try RepoError.throwIfGitError(result)
    
    guard let tree = GitTree(oid: treeOID, repo: git_index_owner(index))
    else {
      throw RepoError.unexpected
    }
    
    return tree
  }
}

extension GitIndex
{
  struct Entry: IndexEntry
  {
    let gitEntry: git_index_entry
    
    var oid: any OID { GitOID(oid: gitEntry.id) }
    var path: String { String(cString: gitEntry.path) }
    
    var conflicted: Bool
    {
      // Even though git_index_entry_is_conflict() takes a const pointer,
      // there's still no easy way to pass it through and make Swift happy.
      return gitEntry.stage > 0
    }
  }
  
  struct ConflictEntry: Xit.ConflictEntry
  {
    let ancestor, ours, theirs: any IndexEntry
  }
  
  class ConflictIterator: IteratorProtocol
  {
    let iterator: OpaquePointer?
    
    init(index: OpaquePointer)
    {
      guard let iterator = try? OpaquePointer.from({
        git_index_conflict_iterator_new(&$0, index)
      })
      else {
        self.iterator = nil
        return
      }
      
      self.iterator = iterator
    }
    
    deinit
    {
      if let iterator = self.iterator {
        git_index_conflict_iterator_free(iterator)
      }
    }
    
    func next() -> (any Xit.ConflictEntry)?
    {
      guard let iterator = self.iterator
      else { return nil }
      var ancestor: UnsafePointer<git_index_entry>? = nil
      var ours: UnsafePointer<git_index_entry>? = nil
      var theirs: UnsafePointer<git_index_entry>? = nil
      let result = git_index_conflict_next(&ancestor, &ours, &theirs, iterator)
      guard result == 0,
            let finalAncestor = ancestor?.pointee,
            let finalOurs = ours?.pointee,
            let finalTheirs = theirs?.pointee
      else { return nil }
      
      return ConflictEntry(ancestor: Entry(gitEntry: finalAncestor),
                           ours: Entry(gitEntry: finalOurs),
                           theirs: Entry(gitEntry: finalTheirs))
    }
  }
}
