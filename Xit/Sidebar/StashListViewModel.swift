import Combine

class StashListViewModel<Stasher, Publisher>: FilteringListViewModel
  where Stasher: Stashing, Publisher: RepositoryPublishing
{
  let stasher: Stasher
  let publisher: Publisher

  @Published var stashes: [Stasher.Stash]

  init(stasher: Stasher, publisher: Publisher)
  {
    self.stasher = stasher
    self.publisher = publisher
    self.stashes = Array(stasher.stashes)
    super.init()

    sinks.append(publisher.stashPublisher.sinkOnMainQueue {
      [weak self] in
      guard let self else { return }
      filterChanged(filter)
    })
  }

  override func filterChanged(_ newFilter: String)
  {
    stashes = stasher.stashes.filter {
      newFilter.isEmpty ||
      $0.message?.lowercased().contains(newFilter.lowercased()) ?? false
    }
  }
}
