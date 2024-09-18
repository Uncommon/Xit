import SwiftUI
import Combine

class BranchListViewModel<Brancher: Branching,
                          Publisher: RepositoryPublishing>: ObservableObject
{
  let brancher: Brancher
  let publisher: Publisher

  var unfilteredList: [PathTreeNode<Brancher.LocalBranch>] = []
  @Published var branches: [PathTreeNode<Brancher.LocalBranch>] = []
  @Published var filter: String = ""

  var sinks: [AnyCancellable] = []

  init(brancher: Brancher, publisher: Publisher)
  {
    self.brancher = brancher
    self.publisher = publisher
    
    updateBranchList()
    sinks.append(contentsOf: [
      publisher.refsPublisher.sinkOnMainQueue {
        [weak self] in
        self?.updateBranchList()
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
}

struct BranchList<Brancher: Branching,
                  Referencer: CommitReferencing,
                  Publisher: RepositoryPublishing>: View
  where Brancher.LocalBranch == Referencer.LocalBranch,
        Brancher.RemoteBranch == Referencer.RemoteBranch
{
  @ObservedObject var model: BranchListViewModel<Brancher, Publisher>

  let brancher: Brancher
  let referencer: Referencer
  let selection: Binding<String?>
  var expandedItems: Binding<Set<String>>

  var body: some View
  {
    VStack(spacing: 0) {
      List(selection: selection) {
        RecursiveDisclosureGroup(model.branches,
                                 expandedItems: expandedItems,
                                 content: branchCell)
      }.overlay {
        if model.branches.isEmpty {
          ContentUnavailableView("No Branches", image: "scm.branch")
        }
      }
      FilterBar(text: $model.filter) {
        SidebarActionButton {
          Button("New branch...") {}
          Button("Rename branch") {}
            .disabled(selection.wrappedValue == nil)
          Button("Delete branch") {}
            .disabled(selection.wrappedValue == nil)
        }
      }
    }
  }
  
  func branchCell(_ node: PathTreeNode<Referencer.LocalBranch>) -> some View
  {
    let branch = node.item
    
    return HStack {
      let isCurrent = branch?.name == brancher.currentBranch?.name
      Label(
        title: {
          Text(node.path.lastPathComponent)
            .bold(isCurrent)
        },
        icon: {
          if let branch {
            if isCurrent {
              Image(systemName: "checkmark.circle").fontWeight(.black)
            }
            else {
              Image("scm.branch")
            }
          }
          else {
            Image(systemName: "folder.fill")
          }
        }
      )
      if let branch {
        // check mark for current branch
        // pull request
        // build status
        upstreamIndicator(for: branch)
      }
    }
      .listRowSeparator(.hidden)
      .selectionDisabled(branch == nil)
  }
  
  func upstreamIndicator(for branch: Referencer.LocalBranch) -> some View
  {
    if let remoteBranch = branch.trackingBranch {
      guard let (ahead, behind) = referencer.graphBetween(
                localBranch: branch,
                upstreamBranch: remoteBranch),
            ahead > 0 && behind > 0
      else {
        return AnyView(Image("network"))
      }
      var numbers = [String]()
      
      if ahead > 0 {
        numbers.append("↑\(ahead)")
      }
      if behind > 0 {
        numbers.append("↓\(behind)")
      }
      return AnyView(StatusBadge(numbers.joined(separator: " ")))
    }
    else {
      return AnyView(EmptyView())
    }
  }
}

#if DEBUG

struct BranchListPreview: View
{
  class Brancher: EmptyBranching, EmptyRepositoryPublishing
  {
    typealias LocalBranch = FakeLocalBranch
    typealias RemoteBranch = FakeRemoteBranch
    
    var localBranchArray: [LocalBranch]
    var remoteBranchArray: [RemoteBranch]
    var localBranches: AnySequence<LocalBranch>
    { .init(localBranchArray) }
    var remoteBranches: AnySequence<FakeRemoteBranch>
    { .init(remoteBranchArray) }
    var currentBranch: LocalBranchRefName?
    
    let publisher = PassthroughSubject<Void, Never>()

    var refsPublisher: AnyPublisher<Void, Never>
    { publisher.eraseToAnyPublisher() }

    init(localBranches: [LocalBranch],
         remoteBranches: [RemoteBranch] = [],
         currentBranch: String? = nil)
    {
      self.localBranchArray = localBranches
      self.remoteBranchArray = remoteBranches
      self.currentBranch = currentBranch
    }

    func localBranch(named refName: LocalBranchRefName) -> LocalBranch?
    {
      localBranchArray.first { $0.name == refName.rawValue }
    }
    
    func createBranch(named name: String, target: String) throws
      -> LocalBranch?
    { nil }

    func localTrackingBranch(forBranch branch: RemoteBranchRefName)
      -> LocalBranch?
    { nil }

    func localBranch(tracking remoteBranch: RemoteBranch) -> LocalBranch?
    { nil }

    func remoteBranch(named name: String) -> RemoteBranch?
    {
      remoteBranchArray.first { $0.name == name }
    }
    
    func remoteBranch(named name: String, remote: String) -> RemoteBranch?
    { nil }
    
    func rename(branch: String, to: String) throws {}
    func reset(toCommit target: any Commit, mode: ResetMode) throws {}
  }
  
  let brancher: Brancher
  @State var selection: String? = nil
  @State var expandedItems: Set<String> = []
  
  typealias CommitReferencer = FakeCommitReferencing<
      NullCommit, FakeTree, Brancher.LocalBranch, Brancher.RemoteBranch>
  
  var body: some View
  {
    BranchList(model: .init(brancher: brancher, publisher: brancher),
               brancher: brancher,
               referencer: CommitReferencer(),
               selection: $selection,
               expandedItems: $expandedItems)
  }
  
  init(localBranches: [String],
       currentBranch: LocalBranchRefName? = nil)
  {
    self.brancher = Brancher(
        localBranches: localBranches.map { .init(name: $0) },
        currentBranch: currentBranch)
  }
}

#Preview
{
  BranchListPreview(localBranches: [
      "master",
      "feature/things",
      "someWork",
    ],
    currentBranch: .init("refs/heads/master"))
}
#endif
