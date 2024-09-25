import Combine

class SubmoduleListModel<Manager: SubmoduleManagement>: ObservableObject
{
  let manager: Manager
  let publisher: any RepositoryPublishing

  var unfilteredList: [any Submodule] = []
  @Published var submodules: [any Submodule] = []
  @Published var filter: String = ""

  var sinks: [AnyCancellable] = []

  init(manager: Manager, publisher: any RepositoryPublishing)
  {
    self.manager = manager
    self.publisher = publisher
    
    updateList()
    sinks.append(contentsOf: [
      publisher.configPublisher.sinkOnMainQueue {
        [weak self] in
        guard let self else { return }
        updateList()
      },
      $filter
        .debounce(for: 0.5, scheduler: DispatchQueue.main)
        .sink {
          [weak self] in
          guard let self else { return }
          filterList(with: $0)
        }
    ])
  }
  
  func updateList()
  {
    unfilteredList = manager.submodules()
    filterList(with: filter)
  }
  
  func filterList(with filter: String)
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
