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

  case local(modified: Bool), remote, tags, stashes, submodules, search, history

  static var cleanCases: [SidebarTab] =
      [.local(modified: false),
       .remote, .tags, .stashes, .submodules, .search, .history]
  static var modifiedCases: [SidebarTab] =
      [.local(modified: true),
       .remote, .tags, .stashes, .submodules, .search, .history]

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
      case .search: Image(systemName: "magnifyingglass")
      case .history: Image(systemName: "square.stack")
    }
  }

  var toolTip: UIString {
    switch self {
      case .local: ›"Local"
      case .remote: .remotes
      case .tags: .tags
      case .stashes: .stashes
      case .submodules: .submodules
      case .search: ›"Search"
      case .history: ›"History"
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

struct TabbedSidebar: View
{
  @State var tab: SidebarTab = .local(modified: false)
  @State var expandedTags: Set<String> = []

  let repoSelection: Binding<(any RepositorySelection)?>
  @State private var selectedTag: String? = nil
  @State private var selectedStash: GitOID? = nil

  @State private var searchRegex: Bool = false
  @State private var searchCaseSensitive: Bool = false

  // These are separate for testing/preview convenience
  //let brancher: any Branching
  //let remoteManager: any RemoteManagement
  let publisher: any RepositoryPublishing
  let stasher: any Stashing
  //let submobuleManager: any SubmoduleManagement
  let tagger: any Tagging

  let remoteData: [TreeLabelItem] = [
    .init(name: "origin", image: .init(systemSymbolName: "network")!, children: [
      .init(name: "branch", image: .xtBranch, children: nil),
      .init(name: "main", image: .xtBranch, children: nil),
    ]),
  ]

  var body: some View {
    VStack(spacing: 0) {
      Divider()
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
          AnyView(tagList(tagger: tagger, publisher: publisher))
        case .stashes:
          AnyView(stashList(stasher: stasher, publisher: publisher))
        case .submodules:
          List {
            Label("submodule1",
                  systemImage: "square.split.bottomrightquarter")
            Label("submodule2",
                  systemImage: "square.split.bottomrightquarter")
          }
        case .search:
          HStack(spacing: 0) {
            Text("Commit messages")
            Spacer()
            Group {
              Toggle("", systemImage: "asterisk.circle", isOn: $searchRegex)
              Toggle("", systemImage: "textformat", isOn: $searchCaseSensitive)
            }.fontWeight(.bold).toggleStyle(.button).buttonStyle(.borderless)
          }
            .padding(4)
            .font(.system(size: NSFont.smallSystemFontSize))
          FilterField(text: .constant("Text"), leftContent: {
            Image(systemName: "magnifyingglass")
          })
            .padding(4)
          Divider()
          Spacer()
          ContentUnavailableView("No results", systemImage: "magnifyingglass")
          Spacer()
        case .history:
          Spacer()
          ContentUnavailableView("No selection", systemImage: "square.stack",
                                 description:
                                  Text("Drag a file here to see its history"))
          Spacer()
      }
    }
      .listStyle(.sidebar)
      .frame(width: 300)
  }

  init(//brancher: any Branching,
       //remoteManager: any RemoteManagement,
       publisher: any RepositoryPublishing,
       stasher: any Stashing,
       //submoduleManager: any SubmoduleManagement,
       tagger: any Tagging,
       selection: Binding<(any RepositorySelection)?>)
  {
    //self.brancher = brancher
    //self.remoteManager = remoteManager
    self.publisher = publisher
    self.stasher = stasher
    //self.submobuleManager = submoduleManager
    self.tagger = tagger
    self.repoSelection = selection
  }

  init(repo: any FullRepository,
       publisher: any RepositoryPublishing,
       selection: Binding<(any RepositorySelection)?>)
  {
    self.init(//brancher: repo, remoteManager: repo,
              publisher: publisher,
              stasher: repo,
              //submoduleManager: repo,
              tagger: repo,
              selection: selection)
  }

  // These views need generic wrappers because the list views are generic
  func tagList(tagger: some Tagging,
               publisher: some RepositoryPublishing) -> some View
  {
    TagList(model: .init(tagger: tagger, publisher: publisher),
            selection: $selectedTag,
            expandedItems: $expandedTags)
      .onChange(of: selectedTag) {
        if let selectedTag,
           let tag = tagger.tag(named: selectedTag),
           let commit = tag.commit,
           let repo = tagger as? any FileChangesRepo {
          repoSelection.wrappedValue = CommitSelection(repository: repo,
                                                       commit: commit)
        }
        else {
          repoSelection.wrappedValue = nil
        }
      }
  }

  func stashList(stasher: some Stashing,
                 publisher: some RepositoryPublishing) -> some View
  {
    StashList(stasher: stasher, publisher: publisher, selection: $selectedStash)
      .onChange(of: selectedStash) {
        if let selectedStash,
           let index = stasher.findStashIndex(selectedStash),
           let repo = stasher as? (any FileChangesRepo & Stashing) {
          repoSelection.wrappedValue = StashSelection(repository: repo,
                                                      index: UInt(index))
        }
        else {
          repoSelection.wrappedValue = nil
        }
      }
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

#if DEBUG
#Preview
{
  let publisher = NullRepositoryPublishing()
  let stasher = StashListPreview.PreviewStashing(["one", "two", "three"])
  let tagger = TagListPreview.Tagger(tagList: [
    .init(name: "someWork"),
    .init(name: "releases/v1.0"),
    .init(name: "releases/v1.1"),
  ])
  return TabbedSidebar(publisher: publisher, stasher: stasher, tagger: tagger,
                       selection: .constant(nil))
}
#endif
