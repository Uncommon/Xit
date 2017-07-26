import Foundation

/// A staging index for creating a commit.
protocol StagingIndex
{
  /* For Swift 4:
  associatedtype Entries: RandomAccessCollection
      where Entries.Iterator.Element: IndexEntry
  
  var entries: Entries
  */
  
  var entries: IndexEntryCollection { get }
  
  /// Reloads the index from the disk.
  func refresh() throws
  /// Saves the index to the disk.
  func save() throws
  /// Returns the entry matching the given file path.
  func entry(at path: String) -> IndexEntry?
  /// Adds a local file to the index
  func add(path: String) throws
  /// Removes a file from the index
  func remove(path: String) throws
}

/// An individual file entry in an index.
protocol IndexEntry
{
  var oid: OID { get }
  var path: String { get }
  var conflicted: Bool { get }
}

// Abstract class so that StagingIndex.entries doesn't have to be an Array.
// In Swift 4 this can go away.
class IndexEntryCollection: RandomAccessCollection
{
  public var startIndex: Int { return 0 }
  public var endIndex: Int { return 0 } // Override
  func index(before i: Int) -> Int { return i - 1 }
  func index(after i: Int) -> Int { return i + 1 }
  
  subscript(position: Int) -> IndexEntry
  {
    return DummyEntry()
  }
  
  // subscript has to return something
  struct DummyEntry: IndexEntry
  {
    var oid: OID { return "" }
    var path: String { return "" }
    var conflicted: Bool { return false }
  }
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
    
    self.index = finalIndex
  }
  
  class EntryCollection: IndexEntryCollection
  {
    let index: GitIndex
    
    public override var endIndex: Int
    {
      return git_index_entrycount(index.index)
    }
    
    override subscript(position: Int) -> IndexEntry
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
  
  var entries: IndexEntryCollection { return EntryCollection(index: self) }
  
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
  
  func add(path: String) throws
  {
    try XTRepository.Error.throwIfError(git_index_add_bypath(index, path))
  }
  
  func remove(path: String) throws
  {
    try XTRepository.Error.throwIfError(git_index_remove_bypath(index, path))
  }
}
