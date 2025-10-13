import SwiftUI

enum RemoteSearchScope: CaseIterable, Identifiable
{
  case branches, remotes
  
  var id: Self { self }
  
  var image: some View
  {
    switch self {
      case .branches: Image("scm.branch")
      case .remotes: Image(systemName: "network")
    }
  }
  
  var text: UIString
  {
    switch self {
      case .branches: .filterBranches
      case .remotes: .filterRemotes
    }
  }
}

@MainActor
protocol RemoteListDelegate
{
  func createTrackingBranch(for branch: RemoteBranchRefName)
}

extension EnvironmentValues
{
  @Entry var remoteListDelegate: (any RemoteListDelegate)? = nil
}


struct RemoteList<Manager: RemoteManagement,
                  Brancher: Branching,
                  Accessorizer: BranchAccessorizing>: View
{
  @StateObject var model: RemoteListViewModel<Manager, Brancher>
  
  let manager: Manager
  let brancher: Brancher
  let accessorizer: Accessorizer
  @Binding var selection: String?
  @Binding var expandedItems: Set<String>
  
  @Environment(\.remoteListDelegate) var delegate

  var body: some View
  {
    VStack(spacing: 0) {
      List(selection: $selection) {
        ForEach(model.remotes, id: \.name) {
          (remote) in
          DisclosureGroup(isExpanded: remoteExpandedBinding(remote.name)) {
            RecursiveDisclosureGroup(remote.branches,
                                     expandedItems: $expandedItems) {
              (node) in
              BranchCell(node: node, trailingContent: {
                if let branch = node.item {
                  accessorizer.accessoryView(for: branch)
                }
              })
            }
          } label: {
            Label(remote.name, systemImage: "network")
          }.listRowSeparator(.hidden)
        }
      }
        .axid(.Sidebar.remotesList)
        .contextMenu(forSelectionType: String.self) {
          selection in
          if let branchRef = selection.first.flatMap({RemoteBranchRefName(rawValue: $0)}) {
            Button(.createTrackingBranch, systemImage: "plus.circle") {
              delegate?.createTrackingBranch(for: branchRef)
            }.axid(.RemoteBranchPopup.createTracking)
          }
        }
        .overlay {
          if model.remotes.isEmpty {
            model.contentUnavailableView("No Remotes", systemImage: "network")
          }
        }
      // TODO: context menu
      FilterBar(text: $model.filter,
                prompt: model.searchScope.text,
                leftContent: {
        SidebarActionButton {
          Button("New remote...", systemImage: "plus") {}
          Button("Rename remote", systemImage: "pencil") {}
          // TODO: enabled specifically if a remote is selected
            .disabled(selection == nil)
          Button("Delete remote", systemImage: "trash") {}
            .disabled(selection == nil)
        }
      }, fieldRightContent: {
        Picker(selection: $model.searchScope, content: {
          ForEach(RemoteSearchScope.allCases) {
            // TODO: Get Picker to use a smaller image size
            $0.image.help($0.text.rawValue)
          }
        }, label: { EmptyView() })
          .pickerStyle(.segmented)
          .frame(maxHeight: 10)
          .fixedSize(horizontal: true, vertical: false)
      })
        // Using a publisher for model.searchScope doesn't work well because
        // it publishes before the change, making it harder to get the new
        // value inside filterChanged()
        .onChange(of: model.searchScope) {
          model.filterChanged(model.filter)
        }
    }
  }
  
  func remoteExpandedBinding(_ remoteName: String) -> Binding<Bool>
  {
    return $model.expandedRemotes.binding(for: remoteName)
  }
}

#if DEBUG
struct RemoteListPreview: View
{
  let manager: FakeRemoteManager
  let brancher: FakeBrancher
  
  @State var selection: String? = nil
  @State var expandedItems: Set<String> = []
  
  var body: some View
  {
    RemoteList(model: .init(manager: manager, brancher: brancher),
               manager: manager,
               brancher: brancher,
               accessorizer: .empty,
               selection: $selection,
               expandedItems: $expandedItems)
  }
}

#Preview
{
  let branches = [
    ("genesis", "main"),
    ("genesis", "superBranch"),
    ("genesis", "superBranch/subBranch"),
    ("origin", "main"),
    ("origin", "feature/thing"),
  ]
  RemoteListPreview(
    manager: .init(remoteNames: ["genesis", "origin"]),
    brancher: .init(remoteBranches: branches.map {
      .init(remoteName: $0.0, name: $0.1)
    }))
}
#endif
