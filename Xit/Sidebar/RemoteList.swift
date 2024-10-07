import SwiftUI

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
    }
  }
  
  func remoteExpandedBinding(_ remoteName: String) -> Binding<Bool>
  {
    return expandedItems.binding(for: RefPrefixes.remotes + remoteName)
  }
}

extension Binding
{
  /// Returns a binding that sets whether or not the given element is included
  /// in the set.
  func binding<S>(for element: S) -> Binding<Bool>
    where Value == Set<S>
  {
    return .init(
      get: { self.wrappedValue.contains(element) },
      set: {
        if $0
        {
          self.wrappedValue.insert(element)
        }
        else
        {
          self.wrappedValue.remove(element)
        }
      })
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
