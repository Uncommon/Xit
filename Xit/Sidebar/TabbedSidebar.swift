import Foundation
import SwiftUI

protocol RepoSelectionItem: Identifiable where ID == String
{
  associatedtype Icon: View
  typealias Element = Self

  var name: String { get }
  var repoSelection: (any RepositorySelection)? { get }
  var image: Icon { get }
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

struct TabbedSidebar: View
{
  @State var tab: SidebarTab = .remote
  @State var expandedTags: Set<String> = []

  let repoSelection: Binding<(any RepositorySelection)?>
  @State private var selectedTag: String? = nil
  @State private var selectedStash: GitOID? = nil

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
              WorkspaceStatusBadge(unstagedCount: 0, stagedCount: 5)
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
