import Foundation

// No protocol here because GitStatusList is only used directly by XTRepository

class GitStatusList: RandomAccessCollection
{
  let statusList: OpaquePointer
  
  public var count: Int
  {
    return git_status_list_entrycount(statusList)
  }
  
  init?(repository: OpaquePointer, show: StatusShow = .indexAndWorkdir,
        options: StatusOptions)
  {
    var gitOptions = git_status_options()
    
    git_status_init_options(&gitOptions, UInt32(GIT_STATUS_OPTIONS_VERSION))
    gitOptions.show = git_status_show_t(rawValue: UInt32(show.rawValue))
    gitOptions.flags = UInt32(options.rawValue)
    
    let list = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    let result = git_status_list_new(list, repository, &gitOptions)
    guard result == 0,
          let finalList = list.pointee
    else { return nil }
    
    self.statusList = finalList
  }
  
  deinit
  {
    git_status_list_free(statusList)
  }
  
  public var startIndex: Int { return 0 }
  public var endIndex: Int { return count }

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
  {
    return StatusFlags(rawValue: Int32(entry.status.rawValue))
  }
  var headToIndex: DiffDelta? { return entry.head_to_index?.pointee }
  var indexToWorkdir: DiffDelta? { return entry.index_to_workdir?.pointee }
}
