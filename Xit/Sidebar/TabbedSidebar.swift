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
//          .symbolRenderingMode(.palette)
//          .foregroundStyle(.secondary, .tint)
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

struct TabbedSidebar<Brancher, Referencer, Stasher, Tagger>: View
  where Brancher: Branching, Referencer: CommitReferencing,
        Stasher: Stashing, Tagger: Tagging,
        Brancher.LocalBranch == Referencer.LocalBranch
{
  @State var tab: SidebarTab = .remote
  @State var expandedBranches: Set<String> = []
  @State var expandedTags: Set<String> = []

  let repoSelection: Binding<(any RepositorySelection)?>
  @State private var selectedBranch: String? = nil
  @State private var selectedTag: String? = nil
  @State private var selectedStash: GitOID? = nil

  // These are separate for testing/preview convenience
  let brancher: Brancher
//  let remoteManager: any RemoteManagement
  let referencer: Referencer
  let publisher: any RepositoryPublishing
  let stasher: Stasher
//  let submobuleManager: any SubmoduleManagement
  let tagger: Tagger
  
  var body: some View {
    VStack(spacing: 0) {
      Divider()
      IconTabPicker(items: SidebarTab.cleanCases, selection: $tab)
        .padding(6)
      Divider()
      switch tab {
        case .local:
          branchList()
        case .remote:
          List {
          }.overlay {
            ContentUnavailableView("No Remotes", systemImage: "network")
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

  init(brancher: Brancher,
//       remoteManager: any RemoteManagement,
       referencer: Referencer,
       publisher: any RepositoryPublishing,
       stasher: Stasher,
//       submoduleManager: any SubmoduleManagement,
       tagger: Tagger,
       selection: Binding<(any RepositorySelection)?>)
  {
    self.brancher = brancher
//    self.remoteManager = remoteManager
    self.referencer = referencer
    self.publisher = publisher
    self.stasher = stasher
//    self.submobuleManager = submoduleManager
    self.tagger = tagger
    self.repoSelection = selection
  }

  private func branchList() -> some View
  {
    BranchList(model: .init(brancher: brancher, publisher: publisher),
                      brancher: brancher,
                      referencer: referencer,
                      accessorizer: .empty,
                      selection: $selectedBranch,
                      expandedItems: $expandedBranches)
      .onChange(of: selectedBranch) {
        guard let selectedBranch,
              let repo = brancher as? any FileChangesRepo
        else {
          repoSelection.wrappedValue = nil
          return
        }
        if selectedBranch.isEmpty {
          repoSelection.wrappedValue = StagingSelection(repository: repo,
                                                        amending: false)
        }
        else if let refName = LocalBranchRefName(selectedBranch),
                let branch = brancher.localBranch(named: refName),
                let commit = branch.targetCommit {
          repoSelection.wrappedValue = CommitSelection(repository: repo,
                                                       commit: commit)
        }
        else {
          repoSelection.wrappedValue = nil
        }
      }
  }

  // These views need generic wrappers because the list views are generic
  private func tagList(tagger: some Tagging,
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

  private func stashList(stasher: some Stashing,
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

#if DEBUG
#Preview
{
  let brancher = BranchListPreview.Brancher(localBranches: [
    "master",
    "feature/things",
    "someWork",
  ].map { .init(name: $0) })
  let publisher = NullRepositoryPublishing()
  let stasher = StashListPreview.PreviewStashing(["one", "two", "three"])
  let tagger = TagListPreview.Tagger(tagList: [
    "someWork",
    "releases/v1.0",
    "releases/v1.1",
  ].map { .init(name: $0) })
  let referencer = BranchListPreview.CommitReferencer()
  
  TabbedSidebar(brancher: brancher, referencer: referencer, publisher: publisher,
                stasher: stasher, tagger: tagger,
                selection: .constant(nil))
}
#endif
