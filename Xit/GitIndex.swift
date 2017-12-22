import Foundation

/// A staging index for creating a commit.
protocol StagingIndex
{
  associatedtype Entries: RandomAccessCollection
      where Entries.Iterator.Element: IndexEntry
   
  var entries: Entries { get }
  
  /// Reloads the index from the disk.
  func refresh() throws
  /// Saves the index to the disk.
  func save() throws
  /// Returns the entry matching the given file path.
  func entry(at path: String) -> IndexEntry?
  /// Adds a local file to the index
  func add(path: String) throws
  /// Adds or updates a file with the given data
  func add(data: Data, path: String) throws
  /// Reads the tree into the index
  func read(tree: Tree) throws
  /// Removes a file from the index
  func remove(path: String) throws
  /// Removes all files
  func clear() throws
}

/// An individual file entry in an index.
protocol IndexEntry
{
  var oid: OID { get }
  var path: String { get }
  var conflicted: Bool { get }
}

/// Staging index implemented with libgit2
class GitIndex: StagingIndex
{
  let index: OpaquePointer
  
  init?(repository: XTRepository)
  {
    var index: OpaquePointer?
    let result = git_repository_index(&index, repository.gtRepo.git_repository())
    guard result == 0,
          let finalIndex = index
    else { return nil }
    
    git_index_read(finalIndex, 1)
    self.index = finalIndex
  }
  
  class EntryCollection: RandomAccessCollection
  {
    let index: GitIndex
    
    var startIndex: Int { return 0 }
    
    public var endIndex: Int
    {
      return git_index_entrycount(index.index)
    }
    
    public subscript(position: Int) -> Entry
    {
      guard let gitEntry = git_index_get_byindex(index.index, position)
      else {
        return Entry(gitEntry: git_index_entry())
      }
      
      return Entry(gitEntry: gitEntry.pointee)
    }
    
    init(index: GitIndex)
    {
      self.index = index
    }
  }
  
  struct Entry: IndexEntry
  {
    let gitEntry: git_index_entry
    
    var oid: OID { return GitOID(oid: gitEntry.id) }
    var path: String { return String(cString: gitEntry.path) }
    
    var conflicted: Bool
    {
      return (UInt32(gitEntry.flags_extended) &
              GIT_IDXENTRY_CONFLICTED.rawValue) != 0
    }
  }
  
  var entries: EntryCollection { return EntryCollection(index: self) }
  
  func entry(at path: String) -> IndexEntry?
  {
    let position = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    guard git_index_find(position, index, path) == 0,
          let entry = git_index_get_byindex(index, position.pointee)
    else { return nil }
    
    return Entry(gitEntry: entry.pointee)
  }
  
  func refresh() throws
  {
    try XTRepository.Error.throwIfError(git_index_read(index, 1))
  }
  
  func save() throws
  {
    try XTRepository.Error.throwIfError(git_index_write(index))
  }
  
  func read(tree: Tree) throws
  {
    guard let gitTree = tree as? GitTree
    else { throw XTRepository.Error.unexpected }
    
    try XTRepository.Error.throwIfError(git_index_read_tree(index, gitTree.tree))
  }
  
  func add(path: String) throws
  {
    try XTRepository.Error.throwIfError(git_index_add_bypath(index, path))
  }
  
  func add(data: Data, path: String) throws
  {
    let result = data.withUnsafeBytes {
      (bytes: UnsafePointer<Int8>) -> Int32 in
      var entry = git_index_entry()
      
      return path.withCString {
        (path) in
        entry.path = path
        entry.mode = GIT_FILEMODE_BLOB.rawValue
        return git_index_add_frombuffer(index, &entry, bytes, data.count)
      }
    }
    
    try XTRepository.Error.throwIfError(result)
  }
  
  func remove(path: String) throws
  {
    try XTRepository.Error.throwIfError(git_index_remove_bypath(index, path))
  }
  
  func clear() throws
  {
    try XTRepository.Error.throwIfError(git_index_clear(index))
  }
}
