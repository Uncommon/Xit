import Combine

class StashListViewModel<Stasher, Publisher>: ObservableObject
  where Stasher: Stashing, Publisher: RepositoryPublishing
{
  let stasher: Stasher
  let publisher: Publisher

  @Published var stashes: [Stasher.Stash]
  @Published var filter: String = ""

  var sinks: [AnyCancellable] = []

  init(stasher: Stasher, publisher: Publisher)
  {
    self.stasher = stasher
    self.publisher = publisher
    self.stashes = Array(stasher.stashes)

    sinks.append(contentsOf: [
      publisher.stashPublisher.sinkOnMainQueue {
        [weak self] in
        guard let self
        else { return }
        applyFilter(filter)
      },
      $filter
        .debounce(for: 0.5, scheduler: DispatchQueue.main)
        .sink {
          [weak self] in
          self?.applyFilter($0)
        },
    ])
  }

  func applyFilter(_ filterString: String)
  {
    stashes = stasher.stashes.filter {
      filterString.isEmpty ||
      $0.message?.lowercased().contains(filterString.lowercased()) ?? false
    }
  }
}
