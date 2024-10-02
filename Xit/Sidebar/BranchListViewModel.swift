import Combine

class BranchListViewModel<Brancher: Branching>: FilteringListViewModel
{
  let brancher: Brancher
  let detector: any FileStatusDetection
  let publisher: any RepositoryPublishing

  var unfilteredList: [PathTreeNode<Brancher.LocalBranch>] = []
  @Published var branches: [PathTreeNode<Brancher.LocalBranch>] = []
  @Published var statusCounts: (staged: Int, unstaged: Int) = (0, 0)

  init(brancher: Brancher,
       detector: any FileStatusDetection,
       publisher: any RepositoryPublishing)
  {
    self.brancher = brancher
    self.detector = detector
    self.publisher = publisher
    super.init()
    
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
    ])
  }
  
  override func filterChanged(_ newFilter: String)
  {
    if newFilter.isEmpty {
      branches = unfilteredList
    }
    else {
      branches = unfilteredList.filtered(with: newFilter)
    }
  }
  
  func updateBranchList()
  {
    let branchList = Array(brancher.localBranches)
    
    unfilteredList = PathTreeNode.makeHierarchy(from: branchList,
                                                prefix: RefPrefixes.heads)
    branches = unfilteredList
  }
  
  func updateCounts()
  {
    statusCounts = (detector.stagedChanges().count,
                    detector.unstagedChanges().count)
  }
}

