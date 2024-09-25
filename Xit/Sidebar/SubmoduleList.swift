import SwiftUI
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

struct SubmoduleList<Manager: SubmoduleManagement>: View
{
  @ObservedObject var model: SubmoduleListModel<Manager>
  let selection: Binding<String?>

  var body: some View
  {
    VStack {
      List(model.submodules, id: \.name, selection: selection) {
        Label($0.name, systemImage: "square.split.bottomrightquarter")
      }.overlay {
        if model.submodules.isEmpty {
          ContentUnavailableView("No Submodules",
                                 systemImage: "square.split.bottomrightquarter")
        }
      }
      FilterBar(text: $model.filter)
    }
  }
}

#if DEBUG
struct SubmoduleListPreview
{
  struct Submodule: Xit.Submodule
  {
    var name: String
    var path: String
    var url: URL?
    
    var ignoreRule: SubmoduleIgnore = .unspecified
    var updateStrategy: SubmoduleUpdate = .default
    var recurse: SubmoduleRecurse = .yes
    
    func update(initialize: Bool, callbacks: RemoteCallbacks) throws {}
  }
  
  class SubmoduleManager: SubmoduleManagement
  {
    var submoduleList: [any Xit.Submodule] = []
    
    func submodules() -> [any Xit.Submodule] { submoduleList }
    func addSubmodule(path: String, url: String) throws {}
    
    init(submodules: [any Xit.Submodule] = [])
    {
      self.submoduleList = submodules
    }
  }
}
#endif
