import SwiftUI
import Combine

protocol BranchAccessorizing<Content>
{
  associatedtype Content: View
  
  func accessoryView(for branch: any ReferenceName) -> Content
}

struct EmptyBranchAccessorizer: BranchAccessorizing
{
  func accessoryView(for branch: any ReferenceName) -> some View { EmptyView() }
}

extension BranchAccessorizing where Self == EmptyBranchAccessorizer
{
  static var empty: EmptyBranchAccessorizer { .init() }
}

@MainActor
// swiftlint:disable:next class_delegate_protocol
protocol BranchListDelegate
{
  func newBranch()
  func checkOut(_ branch: LocalBranchRefName)
  func merge(_ branch: LocalBranchRefName)
  func rename(_ branch: LocalBranchRefName)
  func delete(_ branch: LocalBranchRefName)
}

extension EnvironmentValues
{
  @Entry var branchListDelegate: (any BranchListDelegate)? = nil
}

private let stagingSelectionTag = ""

struct BranchList<Brancher: Branching,
                  Referencer: CommitReferencing,
                  Accessorizer: BranchAccessorizing>: View
  where Brancher.LocalBranch == Referencer.LocalBranch,
        Brancher.RemoteBranch == Referencer.RemoteBranch
{
  @ObservedObject var model: BranchListViewModel<Brancher, Referencer>

  let brancher: Brancher
  let referencer: Referencer
  let accessorizer: Accessorizer
  @Binding var selection: String?
  @Binding var expandedItems: Set<String>

  @Environment(\.branchListDelegate) var delegate: BranchListDelegate?

  var body: some View
  {
    let currentBranch = brancher.currentBranch
    
    VStack(spacing: 0) {
      List(selection: $selection) {
        HStack {
          // stagingCell ID has to go here because putting it
          // on the cell doesn't work.
          Label("Staging", systemImage: "arrow.up.square")
            .axid(.Sidebar.stagingCell)
          Spacer()
          WorkspaceStatusBadge(
              unstagedCount: model.workspaceCountModel.counts.unstaged,
              stagedCount: model.workspaceCountModel.counts.staged)
        }.tag(stagingSelectionTag).listRowSeparator(.hidden)
        // TODO: Reduce the divider height
        // This could be done with .environment(\.defaultMinListRowHeight, x)
        // but then the row height would be dynamic for all other rows which
        // could have a performance impact.
        Divider()
        RecursiveDisclosureGroup(model.branches,
                                 expandedItems: $expandedItems) {
          (node) in
          let isCurrent = node.item?.refName == currentBranch
          BranchCell(node: node,
                     isCurrent: isCurrent,
                     trailingContent: {
            if let item = node.item {
              upstreamIndicator(for: item)
              accessorizer.accessoryView(for: item.refName)
            }
          })
        }
      }
        .axid(.Sidebar.branchList)
        .contextMenu(forSelectionType: String.self) {
          if let ref = branchRef(from: $0) {
            if ref != brancher.currentBranch {
              Button(command: .checkOut) { delegate?.checkOut(ref) }
                .axid(.BranchPopup.checkOut)
            }
            Button(command: .rename) { delegate?.rename(ref) }
              .axid(.BranchPopup.rename)
            Button(command: .merge) { delegate?.merge(ref) }
              .axid(.BranchPopup.merge)
            Divider()
            Button(command: .delete, role: .destructive) { delegate?.delete(ref) }
              .axid(.BranchPopup.delete)
          }
        } primaryAction: {
          if let ref = branchRef(from: $0) {
            delegate?.checkOut(ref)
          }
        }
        .overlay {
          if model.branches.isEmpty {
            model.contentUnavailableView("No Branches", image: "scm.branch")
          }
        }
      FilterBar(text: $model.filter, leftContent: {
        SidebarActionButton {
          let branchRef = selection.flatMap { LocalBranchRefName.named($0) }

          Button("New branch...", systemImage: "plus") {
            delegate?.newBranch()
          }
          Button("Rename branch", systemImage: "pencil") {
            if let branchRef {
              delegate?.rename(branchRef)
            }
          }
            .disabled(branchRef == nil)
          Button("Delete branch", systemImage: "trash") {
            if let branchRef {
              delegate?.delete(branchRef)
            }
          }
            .disabled(branchRef == nil)
        }
      })
    }
  }
  
  func branchRef(from selection: Set<String>) -> LocalBranchRefName?
  {
    selection.first.flatMap { LocalBranchRefName(rawValue: $0) }
  }
  
  func upstreamIndicator(for branch: BranchListItem) -> some View
  {
    if let remoteBranch = branch.trackingRefName {
      // TODO: Cache graphBetween values
      guard let status = referencer.graphBetween(
                localBranch: branch.refName,
                upstreamBranch: remoteBranch),
            status.ahead > 0 && status.behind > 0
      else {
        return AnyView(Image(systemName: "network"))
      }
      var numbers = [String]()
      
      if status.ahead > 0 {
        numbers.append("↑\(status.ahead)")
      }
      if status.behind > 0 {
        numbers.append("↓\(status.behind)")
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
    func accessoryView(for branch: any ReferenceName) -> some View
    {
      let branchName = branch.name
      
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
    let referencer = CommitReferencer()
    BranchList(model: .init(brancher: brancher,
                            referencer: referencer,
                            detector: NullFileStatusDetection(),
                            publisher: brancher,
                            workspaceCountModel: .init()),
               brancher: brancher,
               referencer: referencer,
               accessorizer: brancher,
               selection: $selection,
               expandedItems: $expandedItems)
      .environment(\.branchListDelegate, PrintingBranchDelegate())
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

struct PrintingBranchDelegate: BranchListDelegate
{
  func newBranch()
  { print("new branch") }
  func checkOut(_ branch: LocalBranchRefName)
  { print("check out \(branch.name)") }
  func merge(_ branch: LocalBranchRefName)
  { print("merge \(branch.name)") }
  func rename(_ branch: LocalBranchRefName)
  { print("rename \(branch.name)") }
  func delete(_ branch: LocalBranchRefName)
  { print("delete \(branch.name)") }
}

#Preview
{
  BranchListPreview(localBranches: [
      "master",
      "feature/things",
      "someWork",
    ],
    currentBranch: .init("refs/heads/master"),
                    builtBranches: ["refs/heads/someWork"].map { .named($0)! })
}
#endif
