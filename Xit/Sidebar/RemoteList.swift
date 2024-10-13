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
  
  var text: String
  {
    switch self {
      case .branches: "Search in branches"
      case .remotes: "Search in remotes"
    }
  }
}

struct RemoteList<Manager: RemoteManagement,
                  Brancher: Branching,
                  Accessorizer: BranchAccessorizing>: View
  where Manager.LocalBranch == Brancher.LocalBranch
{
  @StateObject var model: RemoteListViewModel<Manager, Brancher>
  
  let manager: Manager
  let brancher: Brancher
  let accessorizer: Accessorizer
  let selection: Binding<String?>
  var expandedItems: Binding<Set<String>>

  var body: some View
  {
    VStack(spacing: 0) {
      List(selection: selection) {
        ForEach(model.remotes, id: \.name) {
          (remote) in
          DisclosureGroup(isExpanded: remoteExpandedBinding(remote.name)) {
            RecursiveDisclosureGroup(remote.branches,
                                     expandedItems: expandedItems) {
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
      }.overlay {
        if model.remotes.isEmpty {
          ContentUnavailableView("No Remotes", systemImage: "network")
        }
      }
      FilterBar(text: $model.filter, leftContent: {
        SidebarActionButton {
          Button("New remote...") {}
          Button("Rename remote") {}
            .disabled(selection.wrappedValue == nil)
          Button("Delete remote") {}
            .disabled(selection.wrappedValue == nil)
        }
      }, fieldRightContent: {
        Picker(selection: $model.searchScope, content: {
          ForEach(RemoteSearchScope.allCases) {
            // TODO: Get Picker to use a smaller image size
            $0.image.help($0.text)
          }
        }, label: { EmptyView() })
          .pickerStyle(.segmented)
          .frame(maxHeight: 10)
          .fixedSize(horizontal: true, vertical: false)
      })
    }
  }
  
  func remoteExpandedBinding(_ remoteName: String) -> Binding<Bool>
  {
    return expandedItems.binding(for: RefPrefixes.remotes + remoteName)
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
