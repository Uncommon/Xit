import SwiftUI
import Combine

enum BranchTrackingIndicator: Equatable
{
  case none
  case network
  case statusBadge(String)
}

extension BranchListItem
{
  var trackingIndicator: BranchTrackingIndicator
  {
    guard trackingRefName != nil
    else { return .none }

    guard graphStatus.ahead > 0 || graphStatus.behind > 0
    else { return .network }

    var numbers = [String]()

    if graphStatus.ahead > 0 {
      numbers.append("↑\(graphStatus.ahead)")
    }
    if graphStatus.behind > 0 {
      numbers.append("↓\(graphStatus.behind)")
    }
    return .statusBadge(numbers.joined(separator: " "))
  }
}

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
              .contextMenu {
                if let ref = node.item?.refName {
                  branchContextMenu(for: ref)
                }
              }
              .tag(node.item.map { BranchListSelection.branch($0.refName) })
          }
        }
      }
        .axid(.Sidebar.branchList)
        .contextMenu(forSelectionType: BranchListSelection.self) { _ in
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
          let canEditSelection = canEditSelection(branchRef)

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
            .disabled(!canMergeSelection(branchRef))
          Button("Delete branch", systemImage: "trash") {
            if let branchRef {
              coordinator.deleteBranch(branchRef)
            }
          }
            .disabled(!canEditSelection)
        }
      })
    }
      .accessibilityElement(children: .contain)
      .axid(.Sidebar.branchList)
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

  func canEditSelection(_ branchRef: LocalBranchRefName?) -> Bool
  {
    branchRef != nil && branchRef != brancher.currentBranch
  }

  func canMergeSelection(_ branchRef: LocalBranchRefName?) -> Bool
  {
    branchRef != nil && branchRef != brancher.currentBranch
  }

  @ViewBuilder
  func branchContextMenu(for ref: LocalBranchRefName) -> some View
  {
    if ref != brancher.currentBranch {
      Button(command: .checkOut) { coordinator.checkoutBranch(ref) }
        .axid(.BranchPopup.checkOut)
    }
    Button(command: .rename) { coordinator.renameBranch(ref) }
      .axid(.BranchPopup.rename)
      .disabled(!canEditSelection(ref))
    Button(command: .merge) { coordinator.mergeBranch(ref) }
      .axid(.BranchPopup.merge)
      .disabled(!canMergeSelection(ref))
    Divider()
    Button(command: .delete, role: .destructive) {
      coordinator.deleteBranch(ref)
    }
      .axid(.BranchPopup.delete)
      .disabled(!canEditSelection(ref))
  }
  
  func upstreamIndicator(for branch: BranchListItem) -> some View
  {
    switch branch.trackingIndicator {
      case .none:
        return AnyView(EmptyView())

      case .network:
        return AnyView(Image(systemName: "network")
          .axid(.Sidebar.trackingStatus))

      case .statusBadge(let text):
        return AnyView(StatusBadge(text, axid: .Sidebar.trackingStatus))
    }
  }
}

#if false

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
