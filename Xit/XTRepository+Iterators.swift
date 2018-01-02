import Foundation

extension XTRepository
{
  /// Branches is a sequence, not a collection, because the API does not provide
  /// a count or indexed access.
  public struct Branches<BranchType: GitBranch>: Sequence
  {
    public typealias Element = BranchType
    
    let repo: XTRepository
    let type: git_branch_t
    
    public func makeIterator() -> BranchIterator<BranchType>
    {
      return BranchIterator<BranchType>(repo: repo, flags: type)
    }
  }

  public class BranchIterator<BranchType: GitBranch>: IteratorProtocol
  {
    let repo: XTRepository
    let iterator: OpaquePointer?
    
    init(repo: XTRepository, flags: git_branch_t)
    {
      var result: OpaquePointer?
      
      if git_branch_iterator_new(&result, repo.gitRepo, flags) == 0 {
        self.iterator = result
      }
      else {
        self.iterator = nil
      }
      self.repo = repo
    }
    
    public func next() -> BranchType?
    {
      guard let iterator = self.iterator
      else { return nil }
      
      var type = git_branch_t(0)
      var ref: OpaquePointer?
      guard git_branch_next(&ref, &type, iterator) == 0,
            let finalRef = ref
      else { return nil }
      
      return BranchType(branch: finalRef)
    }
    
    deinit
    {
      git_branch_iterator_free(iterator)
    }
  }

  /// The indexable collection of stashes in the repository.
  public class Stashes: Collection
  {
    public typealias Iterator = StashIterator
    
    let repo: XTRepository
    let refLog: OpaquePointer?
    public let count: Int
    
    static let stashRefName = "refs/stash"
    
    init(repo: XTRepository)
    {
      self.repo = repo
      
      let refLogPtr = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
      guard git_reflog_read(refLogPtr, repo.gitRepo, Stashes.stashRefName) == 0
      else {
        self.refLog = nil
        self.count = 0
        return
      }
      
      self.refLog = refLogPtr.pointee
      self.count = git_reflog_entrycount(refLog)
    }
    
    deinit
    {
      git_reflog_free(refLog)
    }
    
    public func makeIterator() -> StashIterator
    {
      return StashIterator(stashes: self)
    }
    
    public subscript(position: Int) -> XTStash
    {
      let entry = git_reflog_entry_byindex(refLog, position)
      let message = String(cString: git_reflog_entry_message(entry))
      
      return XTStash(repo: repo, index: UInt(position), message: message)
    }
    
    public var startIndex: Int { return 0 }
    public var endIndex: Int { return count }
    
    public func index(after i: Int) -> Int
    {
      return i + 1
    }
  }
  
  public class StashIterator: IteratorProtocol
  {
    public typealias Element = XTStash
    
    let stashes: Stashes
    var index: Int
    
    init(stashes: Stashes)
    {
      self.stashes = stashes
      self.index = 0
    }
    
    public func next() -> XTStash?
    {
      let result = stashes[index]
      
      index += 1
      return result
    }
  }
}
