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

private let stagingSelectionTag = ""

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
  let expandedItems: Binding<Set<String>>

  var body: some View
  {
    let currentBranch = brancher.currentBranch
    
    VStack(spacing: 0) {
      List(selection: selection) {
        HStack {
          Label("Staging", systemImage: "arrow.up.square")
          Spacer()
          WorkspaceStatusBadge(unstagedCount: model.statusCounts.unstaged,
                               stagedCount: model.statusCounts.staged)
        }.tag(stagingSelectionTag).listRowSeparator(.hidden)
        // TODO: Reduce the divider height
        // This could be done with .environment(\.defaultMinListRowHeight, x)
        // but then the row height would be dynamic for all other rows which
        // could have a performance impact.
        Divider()
        RecursiveDisclosureGroup(model.branches,
                                 expandedItems: expandedItems) {
          (node) in
          BranchCell(node: node,
                     isCurrent: node.item?.referenceName == currentBranch,
                     trailingContent: {
            if let branch = node.item {
              upstreamIndicator(for: branch)
              accessorizer.accessoryView(for: branch)
            }
          })
        }
      }.overlay {
        if model.branches.isEmpty {
          ContentUnavailableView("No Branches", image: "scm.branch")
        }
      }
      FilterBar(text: $model.filter, leftContent: {
        SidebarActionButton {
          Button("New branch...") {}
          Button("Rename branch") {}
            .disabled(selection.wrappedValue == nil)
          Button("Delete branch") {}
            .disabled(selection.wrappedValue == nil)
        }
      })
    }
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
      let branchName = branch.referenceName.name
      
      if builtBranches.contains(where: { $0.name == branchName }) {
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
    BranchList(model: .init(brancher: brancher,
                            detector: NullFileStatusDetection(),
                            publisher: brancher),
               brancher: brancher,
               referencer: CommitReferencer(),
               accessorizer: brancher,
               selection: $selection,
               expandedItems: $expandedItems)
      .listStyle(.sidebar)
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