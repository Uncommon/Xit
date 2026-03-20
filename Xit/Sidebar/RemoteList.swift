import SwiftUI
import XitGit

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
                  Brancher: Branching>: View
{
  @StateObject var model: RemoteListViewModel<Manager, Brancher>
  
  let manager: Manager
  let brancher: Brancher
  @Binding var selection: RemoteListSelection?
  @Binding var expandedItems: Set<String>
  
  @EnvironmentObject private var coordinator: SidebarCoordinator
  @EnvironmentObject private var accessories: BranchAccessoryStore

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
                  let _ = accessories.revision
                  accessories.accessory(for: branch)
                }
              }, contextMenu: {
                if let branch = node.item {
                  remoteBranchContextMenu(for: branch)
                }
              })
                .tag(node.item.map { RemoteListSelection.branch(ref: $0) })
            }
          } label: {
            remoteRow(for: remote.name)
          }
            .tag(RemoteListSelection.remote(name: remote.name))
            .listRowSeparator(.hidden)
        }
      }
        .axid(.Sidebar.remotesList)
        .contextMenu(forSelectionType: RemoteListSelection.self) { _ in
        }
        .overlay {
          if model.remotes.isEmpty {
            model.contentUnavailableView("No Remotes", systemImage: "network")
          }
        }
      FilterBar(text: $model.filter,
                prompt: model.searchScope.text,
                leftContent: {
        SidebarActionButton {
          let remoteName = selectedRemote

          Button("New remote...", systemImage: "plus") {
            coordinator.newRemote()
          }
          Button("Rename remote", systemImage: "pencil") {
            if let remoteName {
              coordinator.renameRemote(remoteName)
            }
          }
            .disabled(remoteName == nil)
          Button("Edit remote", systemImage: "slider.horizontal.3") {
            if let remoteName {
              coordinator.editRemote(remoteName)
            }
          }
            .disabled(remoteName == nil)
          Button("Delete remote", systemImage: "trash") {
            if let remoteName {
              coordinator.deleteRemote(remoteName)
            }
          }
            .disabled(remoteName == nil)
          Button("Copy remote URL", systemImage: "document.on.document") {
            if let remoteName {
              coordinator.copyRemoteURL(remoteName)
            }
          }
            .disabled(remoteName == nil)
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

  var selectedRemote: String?
  {
    guard case let .remote(name)? = selection
    else { return nil }
    return name
  }
  
  func remoteExpandedBinding(_ remoteName: String) -> Binding<Bool>
  {
    return $model.expandedRemotes.binding(for: remoteName)
  }

  @ViewBuilder
  func remoteContextMenu(for name: String) -> some View
  {
    Button(.rename, systemImage: "pencil") {
      coordinator.renameRemote(name)
    }
    Button(.edit, systemImage: "slider.horizontal.3") {
      coordinator.editRemote(name)
    }
    Button(.delete, systemImage: "trash", role: .destructive) {
      coordinator.deleteRemote(name)
    }
    Button(.copyURL, systemImage: "document.on.document") {
      coordinator.copyRemoteURL(name)
    }
  }

  @ViewBuilder
  func remoteRow(for name: String) -> some View
  {
    HStack {
      Label(name, systemImage: "network")
      Spacer()
    }
      .contentShape(Rectangle())
      .contextMenu {
        remoteContextMenu(for: name)
      }
  }

  @ViewBuilder
  func remoteBranchContextMenu(for branchRef: RemoteBranchRefName) -> some View
  {
    Button(.createTrackingBranch, systemImage: "plus.circle") {
      coordinator.createTrackingBranch(branchRef)
    }
      .axid(.RemoteBranchPopup.createTracking)
    Button(command: .merge) {
      coordinator.mergeRemoteBranch(branchRef)
    }
  }
}

#if false
struct RemoteListPreview: View
{
  let manager: FakeRemoteManager
  let brancher: FakeBrancher
  
  @State var selection: RemoteListSelection? = nil
  @State var expandedItems: Set<String> = []
  
  var body: some View
  {
    RemoteList(model: .init(manager: manager, brancher: brancher,
                            publisher: NullRepositoryPublishing()),
               manager: manager,
               brancher: brancher,
               selection: $selection,
               expandedItems: $expandedItems)
      .environmentObject(SidebarCoordinator())
      .environmentObject(BranchAccessoryStore())
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
