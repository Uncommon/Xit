import Combine

class SubmoduleListModel<Manager: SubmoduleManagement>: FilteringListViewModel
{
  let manager: Manager
  let publisher: any RepositoryPublishing

  var unfilteredList: [any Submodule] = []
  @Published var submodules: [any Submodule] = []

  init(manager: Manager, publisher: any RepositoryPublishing)
  {
    self.manager = manager
    self.publisher = publisher
    super.init()
    
    updateList()
    sinks.append(contentsOf: [
      publisher.configPublisher.sinkOnMainQueue {
        [weak self] in
        guard let self else { return }
        updateList()
      },
    ])
  }
  
  func updateList()
  {
    unfilteredList = manager.submodules()
    filterChanged(filter)
  }
  
  override func filterChanged(_ newFilter: String)
  {
    if filter.isEmpty {
      submodules = unfilteredList
    }
    else {
      let lcFilter = filter.lowercased()
      
      submodules = unfilteredList.filter {
        $0.name.lowercased().contains(lcFilter)
      }
    }
  }
}
