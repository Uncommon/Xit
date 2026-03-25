import Combine

struct BranchListItem: Sendable
{
  let refName: LocalBranchRefName
  let trackingRefName: RemoteBranchRefName?
  let isCurrent: Bool
  let graphStatus: GraphStatus
}

extension BranchListItem: PathTreeData
{
  var treeNodePath: String { refName.fullPath }
}

extension BranchListItem: Identifiable, Hashable
{
  var id: String { refName.rawValue }
  
  static func == (lhs: BranchListItem, rhs: BranchListItem) -> Bool
  {
    lhs.refName == rhs.refName
  }
  
  func hash(into hasher: inout Hasher) { hasher.combine(refName) }
}

class BranchListViewModel<Brancher: Branching,
                          Referencer: CommitReferencing>: FilteringListViewModel
{
  let brancher: Brancher
  let referencer: Referencer
  let statusDetector: any FileStatusDetection
  let publisher: any RepositoryPublishing

  var unfilteredList: [PathTreeNode<BranchListItem>] = []
  @Published var branches: [PathTreeNode<BranchListItem>] = []
  @Published var workspaceCountModel: WorkspaceStatusCountModel

  init(brancher: Brancher,
       referencer: Referencer,
       detector: any FileStatusDetection,
       publisher: any RepositoryPublishing,
       workspaceCountModel: WorkspaceStatusCountModel)
  {
    self.brancher = brancher
    self.referencer = referencer
    self.statusDetector = detector
    self.publisher = publisher
    self.workspaceCountModel = workspaceCountModel
    super.init()
    
    updateBranchList()
    sinks.append(contentsOf: [
      publisher.refsPublisher.sinkOnMainQueue {
        [weak self] in
        self?.updateBranchList()
      },
      // Child model changes must be explicitly forwarded
      workspaceCountModel.objectWillChange.sinkOnMainQueue {
        [weak self] _ in
        self?.objectWillChange.send()
      }
    ])
  }
  
  override func filterChanged(_ newFilter: String)
  {
    branches = newFilter.isEmpty
        ? unfilteredList
        : unfilteredList.filtered(with: newFilter)
  }
  
  func updateBranchList()
  {
    let currentBranch = brancher.currentBranch
    let branchList = brancher.localBranches
      .sorted(byKeyPath: \.referenceName.fullPath)
      .map {
        BranchListItem(refName: $0.referenceName,
                       trackingRefName: $0.trackingBranch?.referenceName,
                       isCurrent: $0.referenceName == currentBranch,
                       graphStatus: branchStatus($0))
      }
    
    unfilteredList = PathTreeNode.makeHierarchy(from: branchList,
                                                prefix: RefPrefixes.heads)
    branches = unfilteredList
  }
  
  func branchStatus(_ branch: Brancher.LocalBranch) -> GraphStatus
  {
    guard let trackingBranch = branch.trackingBranch,
          let status = referencer.graphBetween(
                localBranch: branch.referenceName,
                upstreamBranch: trackingBranch.referenceName)
    else { return .zero }
    
    return status
  }
}
