import Foundation

extension XTRepository
{
  /// Abstract base class for specific iterators
  public class BranchIterator
  {
    let repo: XTRepository
    let iterator: OpaquePointer?
    
    fileprivate init(repo: XTRepository, flags: git_branch_t)
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
    
    fileprivate func nextBranch() -> OpaquePointer?
    {
      guard let iterator = self.iterator
      else { return nil }
      
      var type = git_branch_t(0)
      var ref: OpaquePointer?
      guard git_branch_next(&ref, &type, iterator) == 0,
            let finalRef = ref
      else { return nil }
      
      return finalRef
    }

    deinit
    {
      git_branch_iterator_free(iterator)
    }
  }
  
  /// Iterator for all local branches.
  public class LocalBranchIterator: BranchIterator, IteratorProtocol
  {
    init(repo: XTRepository)
    {
      super.init(repo: repo, flags: GIT_BRANCH_LOCAL)
    }
    
    public func next() -> LocalBranch?
    {
      return nextBranch().map { GitLocalBranch(branch: $0, config: repo.config) }
    }
  }
  
  /// Iterator for all remote branches.
  public class RemoteBranchIterator: BranchIterator, IteratorProtocol
  {
    init(repo: XTRepository)
    {
      super.init(repo: repo, flags: GIT_BRANCH_REMOTE)
    }
    
    public func next() -> RemoteBranch?
    {
      return nextBranch().map { GitRemoteBranch(branch: $0,
                                                config: repo.config) }
    }
  }
  
  /// The indexable collection of stashes in the repository.
  public class StashCollection: Collection
  {
    public typealias Iterator = StashIterator
    
    let repo: XTRepository
    let refLog: OpaquePointer?
    public let count: Int
    
    static let stashRefName = "refs/stash"
    
    init(repo: XTRepository)
    {
      self.repo = repo
      
      var refLogPtr: OpaquePointer? = nil
      guard git_reflog_read(&refLogPtr, repo.gitRepo,
                            StashCollection.stashRefName) == 0
      else {
        self.refLog = nil
        self.count = 0
        return
      }
      
      self.refLog = refLogPtr
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
    
    public subscript(position: Int) -> Stash
    {
      let entry = git_reflog_entry_byindex(refLog, position)
      let message = String(cString: git_reflog_entry_message(entry))
      
      return GitStash(repo: repo, index: UInt(position), message: message)
    }
    
    public var startIndex: Int { 0 }
    public var endIndex: Int { count }
    
    public func index(after i: Int) -> Int
    {
      return i + 1
    }
  }
  
  public class StashIterator: IteratorProtocol
  {
    public typealias Element = Stash
    
    let stashes: StashCollection
    var index: Int
    
    init(stashes: StashCollection)
    {
      self.stashes = stashes
      self.index = 0
    }
    
    public func next() -> Stash?
    {
      guard index < stashes.count
      else { return nil }
      let result = stashes[index]
      
      index += 1
      return result
    }
  }
}
