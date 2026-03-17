import SwiftUI
import Combine

struct BranchList<Brancher: Branching,
                  Referencer: CommitReferencing>: View
  where Brancher.LocalBranch == Referencer.LocalBranch,
        Brancher.RemoteBranch == Referencer.RemoteBranch
{
  @ObservedObject var model: BranchListViewModel<Brancher, Referencer>

  let brancher: Brancher
  let referencer: Referencer
  @Binding var selection: BranchListSelection?
  @Binding var expandedItems: Set<String>

  @EnvironmentObject private var coordinator: SidebarCoordinator
  @EnvironmentObject private var accessories: BranchAccessoryStore

  var body: some View
  {
    let currentBranch = brancher.currentBranch
    
    VStack(spacing: 0) {
      List(selection: $selection) {
        Section {
          HStack {
            // stagingCell ID has to go here because putting it
            // on the cell doesn't work.
            Label("Staging", systemImage: "arrow.up.square")
              .axid(.Sidebar.stagingCell)
            Spacer()
            WorkspaceStatusBadge(
                unstagedCount: model.workspaceCountModel.counts.unstaged,
                stagedCount: model.workspaceCountModel.counts.staged)
          }
            .tag(BranchListSelection.staging)
            .listRowSeparator(.hidden)
        }
        Section {
          RecursiveDisclosureGroup(model.branches,
                                   expandedItems: $expandedItems) {
            (node) in
            let isCurrent = node.item?.refName == currentBranch
            BranchCell(node: node,
                       isCurrent: isCurrent,
                       trailingContent: {
              if let item = node.item {
                upstreamIndicator(for: item)
                let _ = accessories.revision
                accessories.accessory(for: item.refName)
              }
            })
              .tag(node.item.map { BranchListSelection.branch($0.refName) })
          }
        }
      }
        .axid(.Sidebar.branchList)
        .contextMenu(forSelectionType: BranchListSelection.self) {
          if let ref = branchRef(from: $0) {
            if ref != brancher.currentBranch {
              Button(command: .checkOut) { coordinator.checkoutBranch(ref) }
                .axid(.BranchPopup.checkOut)
            }
            Button(command: .rename) { coordinator.renameBranch(ref) }
              .axid(.BranchPopup.rename)
            Button(command: .merge) { coordinator.mergeBranch(ref) }
              .axid(.BranchPopup.merge)
            Divider()
            Button(command: .delete, role: .destructive) {
              coordinator.deleteBranch(ref)
            }
              .axid(.BranchPopup.delete)
          }
        } primaryAction: {
          if let ref = branchRef(from: $0) {
            coordinator.checkoutBranch(ref)
          }
        }
        .overlay {
          if model.branches.isEmpty {
            model.contentUnavailableView("No Branches", image: "scm.branch")
          }
        }
      FilterBar(text: $model.filter, leftContent: {
        SidebarActionButton {
          let branchRef = selectedBranch
          let canEditSelection = branchRef != nil && branchRef != brancher.currentBranch

          Button("New branch...", systemImage: "plus") {
            coordinator.newBranch()
          }
          Button("Rename branch", systemImage: "pencil") {
            if let branchRef {
              coordinator.renameBranch(branchRef)
            }
          }
            .disabled(!canEditSelection)
          Button(command: .merge) {
            if let branchRef {
              coordinator.mergeBranch(branchRef)
            }
          }
            .disabled(branchRef == nil || branchRef == brancher.currentBranch)
          Button("Delete branch", systemImage: "trash") {
            if let branchRef {
              coordinator.deleteBranch(branchRef)
            }
          }
            .disabled(!canEditSelection)
        }
      })
    }
  }
  
  var selectedBranch: LocalBranchRefName?
  {
    guard case let .branch(ref)? = selection
    else { return nil }
    return ref
  }

  func branchRef(from selection: Set<BranchListSelection>) -> LocalBranchRefName?
  {
    guard case let .branch(ref)? = selection.first
    else { return nil }
    return ref
  }
  
  func upstreamIndicator(for branch: BranchListItem) -> some View
  {
    if let remoteBranch = branch.trackingRefName {
      // TODO: Cache graphBetween values
      guard let status = referencer.graphBetween(
                localBranch: branch.refName,
                upstreamBranch: remoteBranch),
            status.ahead > 0 || status.behind > 0
      else {
        return AnyView(Image(systemName: "network")
          .axid(.Sidebar.trackingStatus))
      }
      var numbers = [String]()
      
      if status.ahead > 0 {
        numbers.append("↑\(status.ahead)")
      }
      if status.behind > 0 {
        numbers.append("↓\(status.behind)")
      }
      return AnyView(StatusBadge(numbers.joined(separator: " "),
                                 axid: .Sidebar.trackingStatus))
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
         currentBranch: LocalBranchRefName? = nil)
    {
      self.localBranchArray = localBranches
      self.remoteBranchArray = remoteBranches
      self.currentBranch = currentBranch
    }

    func localBranch(named refName: LocalBranchRefName) -> LocalBranch?
    {
      localBranchArray.first { $0.name == refName.rawValue }
    }
    
    func remoteBranch(named name: String) -> RemoteBranch?
    {
      remoteBranchArray.first { $0.name == name }
    }
    
  }
  
  let brancher: Brancher
  @State var selection: BranchListSelection? = nil
  @State var expandedItems: Set<String> = []
  
  typealias CommitReferencer = FakeCommitReferencing<
      NullCommit, FakeTree, Brancher.LocalBranch, Brancher.RemoteBranch>
  
  var body: some View
  {
    let referencer = CommitReferencer()
    BranchList(model: .init(brancher: brancher,
                            referencer: referencer,
                            detector: NullFileStatusDetection(),
                            publisher: brancher,
                            workspaceCountModel: .init()),
               brancher: brancher,
               referencer: referencer,
               selection: $selection,
               expandedItems: $expandedItems)
      .environmentObject(SidebarCoordinator())
      .environmentObject(BranchAccessoryStore())
      .listStyle(.sidebar)
      .frame(maxWidth: 250)
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
