import Foundation
import SwiftUI

protocol RepoSelectionItem: Identifiable where ID == String {
  associatedtype Icon: View
  typealias Element = Self

  var name: String { get }
  var repoSelection: (any RepositorySelection)? { get }
  var image: Icon { get }
}


protocol SidebarTreeItem: RepoSelectionItem
{
  var children: [any SidebarTreeItem]? { get }
}

enum RemoteItemContent
{
  indirect case remote(String, [RemoteItemContent])
  indirect case folder(String, [RemoteItemContent])
  case branch(String)
}

struct RemoteTreeItem: SidebarTreeItem
{
  let content: RemoteItemContent
  let name: String
  var children: [any SidebarTreeItem]? {
    switch content {
      case .remote: []
      case .folder: []
      case .branch: nil
    }
  }

  var image: some View {
    switch content {
      case .remote: Image(systemName: "network")
      case .folder: Image(systemName: "folder")
      case .branch: Image("scm.branch")
    }
  }

  var repoSelection: (any RepositorySelection)? { nil }
}

extension RemoteTreeItem: Identifiable
{
  var id: String { name }
}

struct FolderTreeItem: SidebarTreeItem
{
  let name: String
  let children: [any SidebarTreeItem]?
  var image: some View { Image(systemName: "folder") }

  var repoSelection: (any RepositorySelection)? { nil }
}

extension FolderTreeItem: Identifiable
{
  var id: String { name }
}

enum SidebarTab: TabItem, Hashable
{
  typealias ID = Self

  case local(modified: Bool), remote, tags, stashes, submodules

  static var cleanCases: [SidebarTab] =
      [.local(modified: false), .remote, .tags, .stashes, .submodules]
  static var modifiedCases: [SidebarTab] =
      [.local(modified: true), .remote, .tags, .stashes, .submodules]

  var id: Self
  {
    switch self {
      case .local: .local(modified: false)
      default: self
    }
  }

  @ViewBuilder
  var icon: some View
  {
    switch self {
      case .local(true): Image("externaldrive.badge")
          //.symbolRenderingMode(.palette)
          //.foregroundStyle(.secondary, .tint)
      case .local(modified: false): Image(systemName: "externaldrive")
      case .remote: Image(systemName: "network")
      case .tags: Image(systemName: "tag")
      case .stashes: Image(systemName: "tray")
      case .submodules: Image(systemName: "square.split.bottomrightquarter")
    }
  }

  var toolTip: UIString {
    switch self {
      case .local: ›"Local"
      case .remote: .remotes
      case .tags: .tags
      case .stashes: .stashes
      case .submodules: .submodules
    }
  }
}

struct TreeLabelItem {
  let name: String
  let image: NSImage
  let children: [TreeLabelItem]?
}
extension TreeLabelItem: Identifiable { var id: String { name } }

struct TreeLabelList: View
{
  let items: [TreeLabelItem]
  var body: some View {
    List(items, children: \.children) { item in
      Label(title: { Text(item.name) },
            icon: { Image(nsImage: item.image) })
    }
  }
}

struct SidebarTabs: View
{
  @State var tab: SidebarTab = .remote

  // These are separate for testing/preview convenience
  //let brancher: any Branching
  //let remoteManager: any RemoteManagement
  let publisher: any RepositoryPublishing
  let stasher: any Stashing
  //let submobuleManager: any SubmoduleManagement
  //let tagger: any Tagging

  let remoteData: [TreeLabelItem] = [
    .init(name: "origin", image: .init(systemSymbolName: "network")!, children: [
      .init(name: "branch", image: .xtBranch, children: nil),
      .init(name: "main", image: .xtBranch, children: nil),
    ]),
  ]

  var body: some View {
    VStack(spacing: 0) {
      IconTabPicker(items: SidebarTab.cleanCases, selection: $tab)
        .padding(6)
      Divider()
      switch tab {
        case .local:
          List {
            HStack {
              Label("Staging", systemImage: "folder")
              Spacer()
              WorkspaceStatusView(unstagedCount: 0, stagedCount: 5)
            }
            Divider()
            Label("branch", image: "scm.branch")
            Label("main", image: "scm.branch")
          }
        case .remote:
          List(remoteData, children: \.children) { item in
            Label(title: { Text(item.name) },
                  icon: { Image(nsImage: item.image) })
          }
        case .tags:
          List {
            tagCell("someTag", annotated: true)
            tagCell("otherTag", annotated: false)
          }
        case .stashes:
          AnyView(stashList(stasher: stasher, publisher: publisher))
        case .submodules:
          List {
            Label("submodule1",
                  systemImage: "square.split.bottomrightquarter")
            Label("submodule2",
                  systemImage: "square.split.bottomrightquarter")
          }
      }
    }
      .listStyle(.sidebar)
      .frame(width: 300)
  }

  init(//brancher: any Branching,
       //remoteManager: any RemoteManagement,
       publisher: any RepositoryPublishing,
       stasher: any Stashing
       //submoduleManager: any SubmoduleManagement,
       //tagger: any Tagging
  )
  {
    //self.brancher = brancher
    //self.remoteManager = remoteManager
    self.publisher = publisher
    self.stasher = stasher
    //self.submobuleManager = submoduleManager
    //self.tagger = tagger
  }

  init(repo: any FullRepository, publisher: any RepositoryPublishing)
  {
    self.init(//brancher: repo, remoteManager: repo,
              publisher: publisher,
              stasher: repo
              //submoduleManager: repo, tagger: repo
    )
  }

  // Needs a generic wrapper because StashList is generic
  func stashList(stasher: some Stashing,
                 publisher: some RepositoryPublishing) -> some View
  {
    StashList(stasher: stasher, publisher: publisher)
  }

  func tagCell(_ name: String, annotated: Bool) -> some View {
    Label(name, systemImage: "tag")
      .symbolVariant(annotated ? .fill : .none)
  }
}

/// Action pop-up button that goes next to the filter field at the bottom
/// of the sidebar
struct SidebarActionButton<Content: View>: View
{
  let content: () -> Content

  var body: some View
  {
    Menu(content: content, label: {
      Image(systemName: "ellipsis.circle")
    })
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .frame(width: 24)
  }

  init(@ViewBuilder content: @escaping () -> Content)
  {
    self.content = content
  }
}

struct WorkspaceStatusView: View
{
  let unstagedCount, stagedCount: Int

  var body: some View {
    Text("\(unstagedCount) ▸ \(stagedCount)")
      .padding(EdgeInsets(top: 1, leading: 5, bottom: 1, trailing: 5))
      .background(Color(nsColor: .controlColor))
      .clipShape(.capsule)
      .font(.system(size: 10))
  }
}

#Preview
{
  let repo = StashListPreview.PreviewStashing(["one", "two", "three"])
  return SidebarTabs(publisher: repo, stasher: repo)
}
