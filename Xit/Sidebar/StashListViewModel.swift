import Combine

class StashListViewModel<Stasher: Stashing>: FilteringListViewModel
{
  let stasher: Stasher

  @Published var stashes: [Stasher.Stash]

  init(stasher: Stasher, publisher: any RepositoryPublishing)
  {
    self.stasher = stasher
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
