import Foundation

// No protocol here because GitStatusList is only used directly by XTRepository

class GitStatusList: RandomAccessCollection
{
  let statusList: OpaquePointer
  
  public var count: Int
  { git_status_list_entrycount(statusList) }
  
  init?(repository repo: XTRepository, show: StatusShow = .indexAndWorkdir,
        options: StatusOptions)
  {
    var gitOptions = git_status_options.defaultOptions()
    
    gitOptions.show = git_status_show_t(rawValue: UInt32(show.rawValue))
    gitOptions.flags = UInt32(options.rawValue)
    if options.contains(.amending),
       let headCommit = repo.headSHA.flatMap({ repo.commit(forSHA: $0) }),
       let previousCommit = headCommit.parentOIDs.first
                                      .flatMap({ repo.commit(forOID: $0) }) {
      gitOptions.baseline = (previousCommit.tree as? GitTree)?.tree
    }
    
    guard let list = try? OpaquePointer.from({
      git_status_list_new(&$0, repo.gitRepo, &gitOptions)
    })
    else { return nil }
    
    self.statusList = list
  }
  
  deinit
  {
    git_status_list_free(statusList)
  }
  
  public var startIndex: Int { 0 }
  public var endIndex: Int { count }

  subscript(index: Int) -> GitStatusEntry
  {
    guard let entry = git_status_byindex(statusList, index)
    else { return GitStatusEntry(entry: git_status_entry()) }
    
    return GitStatusEntry(entry: entry.pointee)
  }
}

struct GitStatusEntry
{
  let entry: git_status_entry
  
  var status: StatusFlags
  { StatusFlags(rawValue: Int32(entry.status.rawValue)) }
  
  var headToIndex: DiffDelta? { entry.head_to_index?.pointee }
  var indexToWorkdir: DiffDelta? { entry.index_to_workdir?.pointee }
}
