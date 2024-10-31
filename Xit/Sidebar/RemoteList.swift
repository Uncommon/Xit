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

struct RemoteList<Manager: RemoteManagement,
                  Brancher: Branching,
                  Accessorizer: BranchAccessorizing>: View
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
          model.contentUnavailableView("No Remotes", systemImage: "network")
        }
      }
      FilterBar(text: $model.filter,
                prompt: model.searchScope.text,
                leftContent: {
        SidebarActionButton {
          Button("New remote...") {}
          Button("Rename remote") {}
          // TODO: enabled specifically if a remote is selected
            .disabled(selection.wrappedValue == nil)
          Button("Delete remote") {}
            .disabled(selection.wrappedValue == nil)
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
