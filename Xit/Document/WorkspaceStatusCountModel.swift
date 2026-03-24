import Combine

/// Model that tracks the count of staged and unstaged files.
@MainActor
class WorkspaceStatusCountModel: ObservableObject
{
  @Published
  var counts: (staged: Int, unstaged: Int) = (0, 0)
  
  var indexSubscription: AnyCancellable?
  var workspaceSubscription: AnyCancellable?
  
  func readStatus(from detector: some FileStatusDetection)
  {
    counts = (detector.stagedChanges().count,
              detector.unstagedChanges().count)
  }
  
  func subscribe(to publisher: some RepositoryPublishing,
                 detector: some FileStatusDetection)
  {
    self.readStatus(from: detector)
    indexSubscription = publisher.indexPublisher.sink {
      self.readStatus(from: detector)
    }
    workspaceSubscription = publisher.workspacePublisher.sink {
      _ in
      self.readStatus(from: detector)
    }
  }
}
