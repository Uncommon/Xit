import Combine

class BranchListViewModel<Brancher: Branching>: ObservableObject
{
  let brancher: Brancher
  let detector: any FileStatusDetection
  let publisher: any RepositoryPublishing

  var unfilteredList: [PathTreeNode<Brancher.LocalBranch>] = []
  @Published var branches: [PathTreeNode<Brancher.LocalBranch>] = []
  @Published var filter: String = ""
  @Published var statusCounts: (staged: Int, unstaged: Int) = (0, 0)

  var sinks: [AnyCancellable] = []

  init(brancher: Brancher,
       detector: any FileStatusDetection,
       publisher: any RepositoryPublishing)
  {
    self.brancher = brancher
    self.detector = detector
    self.publisher = publisher
    
    updateBranchList()
    updateCounts()
    sinks.append(contentsOf: [
      publisher.refsPublisher.sinkOnMainQueue {
        [weak self] in
        self?.updateBranchList()
      },
      publisher.indexPublisher.sinkOnMainQueue {
        [weak self] in
        self?.updateCounts()
      },
      publisher.workspacePublisher.sinkOnMainQueue {
        [weak self] _ in
        self?.updateCounts()
      },
      $filter
        .debounce(for: 0.5, scheduler: DispatchQueue.main)
        .sink {
          [weak self] in
          guard let self else { return }
          if $0.isEmpty {
            branches = unfilteredList
          }
          else {
            branches = unfilteredList.filtered(with: $0)
          }
        }
    ])
  }
  
  func updateBranchList()
  {
    let branchList = Array(brancher.localBranches)
    
    unfilteredList = PathTreeNode.makeHierarchy(from: branchList)
    branches = unfilteredList
  }
  
  func updateCounts()
  {
    statusCounts = (detector.stagedChanges().count,
                    detector.unstagedChanges().count)
  }
}

