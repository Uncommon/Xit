import SwiftUI

enum RemoteSearchScope: CaseIterable, Identifiable, TabItem
{
  case branches, remotes
  
  var id: Self { self }
  
  var icon: some View
  {
    switch self {
      case .branches: Image("scm.branch")
      case .remotes: Image(systemName: "network")
    }
  }
  
  var toolTip: UIString
  {
    switch self {
      case .branches: .filterBranches
      case .remotes: .filterRemotes
    }
  }

  var text: UIString
  { toolTip }
}

enum RemoteTreeItem: PathTreeData, Hashable
{
  case remote(String)
  case branch(RemoteBranchRefName)

  var treeNodePath: String
  {
    switch self {
      case .remote(let name):
        name
      case .branch(let ref):
        ref.name
    }
  }
}

struct RemoteList<Manager: RemoteManagement,
                  Brancher: Branching>: View
{
  @StateObject var model: RemoteListViewModel<Manager, Brancher>
  /// `List` mutates this state during selection updates. Keeping it local
  /// avoids publishing back into the coordinator from inside a view update.
  @State private var listSelection: RemoteListSelection?
  /// Local mirror of the outline expansion state for the same reason as
  /// `listSelection`.
  @State private var listExpandedItems: Set<String>
  
  /// Source of truth shared with the coordinator. This is synchronized with
  /// `listSelection` asynchronously to avoid SwiftUI's "publishing changes
  /// from within view updates" warning.
  @Binding var selection: RemoteListSelection?
  @Binding var expandedItems: Set<String>
  
  @EnvironmentObject private var coordinator: SidebarCoordinator
  @EnvironmentObject private var accessories: BranchAccessoryStore

  var body: some View
  {
    VStack(spacing: 0) {
      List(selection: $listSelection) {
        RecursiveDisclosureGroup(treeItems, expandedItems: $listExpandedItems) {
          (node) in
          row(for: node)
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
        IconPicker(items: RemoteSearchScope.allCases,
                   selection: $model.searchScope,
                   showsDividers: false,
                   spacing: 0)
      })
        // Using a publisher for model.searchScope doesn't work well because
        // it publishes before the change, making it harder to get the new
        // value inside filterChanged()
        .onChange(of: model.searchScope) {
          model.filterChanged(model.filter)
        }
        .onChange(of: listSelection) {
          let newSelection = listSelection
          guard selection != newSelection
          else { return }
          DispatchQueue.main.async {
            selection = newSelection
          }
        }
        .onChange(of: selection) {
          guard listSelection != selection
          else { return }
          listSelection = selection
        }
        .onChange(of: listExpandedItems) {
          let newExpanded = listExpandedItems
          guard expandedItems != newExpanded
          else { return }
          DispatchQueue.main.async {
            expandedItems = newExpanded
          }
        }
        .onChange(of: expandedItems) {
          guard listExpandedItems != expandedItems
          else { return }
          listExpandedItems = expandedItems
        }
    }
      .accessibilityElement(children: .contain)
      .axid(.Sidebar.remotesList)
  }

  var selectedRemote: String?
  {
    guard case let .remote(name)? = listSelection
    else { return nil }
    return name
  }

  var treeItems: [PathTreeNode<RemoteTreeItem>]
  {
    let items = model.remotes.flatMap {
      [RemoteTreeItem.remote($0.name)] + flattenedBranchItems(in: $0.branches)
    }
    return PathTreeNode.makeHierarchy(from: items)
  }

  func flattenedBranchItems(in nodes: [PathTreeNode<RemoteBranchRefName>])
      -> [RemoteTreeItem]
  {
    nodes.flatMap {
      ($0.item.map { [RemoteTreeItem.branch($0)] } ?? []) +
          flattenedBranchItems(in: $0.children ?? [])
    }
  }

  @ViewBuilder
  func row(for node: PathTreeNode<RemoteTreeItem>) -> some View
  {
    switch node.item {
      case .remote(let name):
        remoteRow(for: name)
          .tag(RemoteListSelection.remote(name: name))
          .listRowSeparator(.hidden)
      case .branch(let branch):
        remoteBranchRow(for: node, branch: branch)
      case nil:
        folderRow(for: node.path.lastPathComponent)
    }
  }

  @ViewBuilder
  func remoteBranchRow(for node: PathTreeNode<RemoteTreeItem>,
                       branch: RemoteBranchRefName) -> some View
  {
    HStack {
      Label {
        ExpansionText(node.path.lastPathComponent,
                      font: .systemFontSized(weight: .regular))
          .padding(.horizontal, 4)
          .cornerRadius(4)
          .accessibilityIdentifier("branch")
      } icon: {
        Image("scm.branch")
      }
      Spacer()
      let _ = accessories.revision
      accessories.accessory(for: branch)
    }
      .contentShape(Rectangle())
      .listRowSeparator(.hidden)
      .contextMenu {
        remoteBranchContextMenu(for: branch)
      }
      .tag(RemoteListSelection.branch(ref: branch))
  }

  @ViewBuilder
  func folderRow(for name: String) -> some View
  {
    HStack {
      Label(name, systemImage: "folder.fill")
      Spacer()
    }
      .contentShape(Rectangle())
      .listRowSeparator(.hidden)
      .selectionDisabled(true)
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

  init(model: RemoteListViewModel<Manager, Brancher>,
       selection: Binding<RemoteListSelection?>,
       expandedItems: Binding<Set<String>>)
  {
    self._model = StateObject(wrappedValue: model)
    self._selection = selection
    self._expandedItems = expandedItems
    self._listSelection = State(initialValue: selection.wrappedValue)
    self._listExpandedItems = State(initialValue: expandedItems.wrappedValue)
  }
}

#if DEBUG
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
