import SwiftUI
import Combine

protocol BranchAccessorizing<Content>
{
  associatedtype Content: View
  
  func accessoryView(for branch: any Branch) -> Content
}

struct EmptyBranchAccessorizer: BranchAccessorizing
{
  func accessoryView(for branch: any Branch) -> some View { EmptyView() }
}

extension BranchAccessorizing where Self == EmptyBranchAccessorizer
{
  static var empty: EmptyBranchAccessorizer { .init() }
}

class BranchListViewModel<Brancher: Branching>: ObservableObject
{
  let brancher: Brancher
  let publisher: any RepositoryPublishing

  var unfilteredList: [PathTreeNode<Brancher.LocalBranch>] = []
  @Published var branches: [PathTreeNode<Brancher.LocalBranch>] = []
  @Published var filter: String = ""

  var sinks: [AnyCancellable] = []

  init(brancher: Brancher, publisher: any RepositoryPublishing)
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
                  Accessorizer: BranchAccessorizing>: View
  where Brancher.LocalBranch == Referencer.LocalBranch,
        Brancher.RemoteBranch == Referencer.RemoteBranch
{
  @ObservedObject var model: BranchListViewModel<Brancher>

  let brancher: Brancher
  let referencer: Referencer
  let accessorizer: Accessorizer
  let selection: Binding<String?>
  var expandedItems: Binding<Set<String>>

  var body: some View
  {
    VStack(spacing: 0) {
      List(selection: selection) {
        HStack {
          Label("Staging", systemImage: "folder")
          Spacer()
          WorkspaceStatusBadge(unstagedCount: 0, stagedCount: 5)
        }
        Divider()
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
      let isCurrent = branch?.name == brancher.currentBranch?.rawValue
      Label(
        title: {
          Text(node.path.lastPathComponent)
            .bold(isCurrent)
            .padding(.horizontal, 4)
            // tried hiding this background when the row is selected,
            // but there is a delay so it doesn't look good.
            .background(isCurrent
                        ? AnyShapeStyle(.quaternary)
                        : AnyShapeStyle(.clear))
            .cornerRadius(4)
        },
        icon: {
          if branch == nil {
            Image(systemName: "folder.fill")
          }
          else {
            if isCurrent {
              Image(systemName: "checkmark.circle").fontWeight(.black)
            }
            else {
              Image("scm.branch")
            }
          }
        }
      )
      Spacer()
      if let branch {
        upstreamIndicator(for: branch)
        accessorizer.accessoryView(for: branch)
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
        return AnyView(Image(systemName: "network"))
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
  class Brancher: EmptyBranching, EmptyRepositoryPublishing, BranchAccessorizing
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
    
    let builtBranches: [LocalBranchRefName]

    init(localBranches: [LocalBranch],
         remoteBranches: [RemoteBranch] = [],
         currentBranch: LocalBranchRefName? = nil,
         builtBranches: [LocalBranchRefName] = [])
    {
      self.localBranchArray = localBranches
      self.remoteBranchArray = remoteBranches
      self.currentBranch = currentBranch
      self.builtBranches = builtBranches
    }

    func localBranch(named refName: LocalBranchRefName) -> LocalBranch?
    {
      localBranchArray.first { $0.name == refName.rawValue }
    }
    
    func remoteBranch(named name: String) -> RemoteBranch?
    {
      remoteBranchArray.first { $0.name == name }
    }
    
    @ViewBuilder
    func accessoryView(for branch: any Branch) -> some View
    {
      if builtBranches.contains(where: { $0.name == branch.strippedName }) {
        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
      }
    }
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
               accessorizer: brancher,
               selection: $selection,
               expandedItems: $expandedItems)
      .frame(maxWidth: 250)
  }
  
  init(localBranches: [String],
       currentBranch: LocalBranchRefName? = nil,
       builtBranches: [LocalBranchRefName] = [])
  {
    self.brancher = Brancher(
        localBranches: localBranches.map { .init(name: $0) },
        currentBranch: currentBranch,
        builtBranches: builtBranches)
  }
}

#Preview
{
  BranchListPreview(localBranches: [
      "master",
      "feature/things",
      "someWork",
    ],
    currentBranch: .init("refs/heads/master"),
                    builtBranches: ["refs/heads/someWork"].map { .init($0)! })
}
#endif
