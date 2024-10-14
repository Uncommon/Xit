import Combine

class FilteringListViewModel: ObservableObject
{
  @Published var filter: String = ""
  var sinks: [AnyCancellable] = []
  
  init()
  {
    sinks.append($filter
      .debounce(for: 0.5, scheduler: DispatchQueue.main)
      .sink {
        [weak self] in
        self?.filterChanged($0)
      }
    )
  }
  
  func filterChanged(_ newFilter: String)
  {
    assertionFailure("filterChanged not implemented")
  }
}
