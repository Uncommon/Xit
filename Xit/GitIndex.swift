import Foundation

protocol StagingIndex
{
  /* For Swift 4:
  associatedtype Entries: RandomAccessCollection
      where Entries.Iterator.Element: IndexEntry
  
  var entries: Entries
  */
  
  var entries: IndexEntryCollection { get }
  
  func refresh()
}

protocol IndexEntry
{
  var oid: OID { get }
  var path: String { get }
  var conflicted: Bool { get }
}

// Abstract class so that StagingIndex.entries doesn't have to be an Array
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
  
  func refresh()
  {
    git_index_read(index, 1)
  }
}
