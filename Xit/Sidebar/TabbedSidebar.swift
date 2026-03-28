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

  var toolTip: UIString
  {
    switch self {
      case .local: .branches
      case .remote: .remotes
      case .tags: .tags
      case .stashes: .stashes
      case .submodules: .submodules
    }
  }
}

let sidebarDateFormatStyle = Date.FormatStyle()
  .day(.twoDigits)
  .month(.twoDigits)
  .year(.twoDigits)

extension FormatStyle where Self == Date.FormatStyle
{
  static var sidebar: Self { sidebarDateFormatStyle }
}

struct TabbedSidebar<Brancher, Manager, Referencer, Stasher, Tagger, SubManager>
  : View
  where Brancher: Branching, Manager: RemoteManagement,
        Referencer: CommitReferencing,
        Stasher: Stashing, Tagger: Tagging, SubManager: SubmoduleManagement,
        Brancher.LocalBranch == Referencer.LocalBranch,
        Brancher.RemoteBranch == Referencer.RemoteBranch
{
  // These are separate for testing/preview convenience
  let brancher: Brancher
  let remoteManager: Manager
  let referencer: Referencer
  let publisher: any RepositoryPublishing
  let stasher: Stasher
  let submobuleManager: SubManager
  let tagger: Tagger

  let models: SidebarViewModel<Brancher, Manager, Referencer, Stasher,
                               Tagger, SubManager>
  @EnvironmentObject private var coordinator: SidebarCoordinator
  @EnvironmentObject private var accessories: BranchAccessoryStore
  
  var body: some View {
    VStack(spacing: 0) {
      Divider()
      IconTabPicker(items: SidebarTab.cleanCases,
                    selection: $coordinator.activeTab)
        .padding(6)
      Divider()
      switch coordinator.activeTab {
        case .local:
          branchList()
        case .remote:
          remoteList()
        case .tags:
          AnyView(tagList(tagger: tagger, publisher: publisher))
        case .stashes:
          AnyView(stashList(publisher: publisher))
        case .submodules:
          AnyView(submoduleList(manager: submobuleManager))
      }
    }
      .listStyle(.sidebar)
      .frame(width: 300)
      .accessibilityElement(children: .contain)
      .axid(.Sidebar.list)
  }

  init(brancher: Brancher,
       remoteManager: Manager,
       referencer: Referencer,
       publisher: any RepositoryPublishing,
       stasher: Stasher,
       submoduleManager: SubManager,
       tagger: Tagger,
       models: SidebarViewModel<Brancher, Manager, Referencer, Stasher,
                                Tagger, SubManager>)
  {
    self.brancher = brancher
    self.remoteManager = remoteManager
    self.referencer = referencer
    self.publisher = publisher
    self.stasher = stasher
    self.submobuleManager = submoduleManager
    self.tagger = tagger
    self.models = models
  }

  private func branchList() -> some View
  {
    BranchList(model: models.branchModel,
               brancher: brancher,
               referencer: referencer,
               selection: $coordinator.branchSelection,
               expandedItems: $coordinator.expandedBranches)
      .environmentObject(accessories)
  }
  
  private func remoteList() -> some View
  {
    RemoteList(model: models.remoteModel,
               selection: $coordinator.remoteSelection,
               expandedItems: $coordinator.expandedRemotes)
      .environmentObject(accessories)
  }

  // These views need generic wrappers because the list views are generic
  private func tagList(tagger: some Tagging,
                       publisher _: some RepositoryPublishing) -> some View
  {
    TagList(model: models.tagModel,
            selection: $coordinator.tagSelection,
            expandedItems: $coordinator.expandedTags)
  }

  private func stashList(publisher: some RepositoryPublishing) -> some View
  {
    StashList(model: models.stashModel,
              stasher: stasher,
              publisher: publisher,
              selection: $coordinator.stashSelection)
  }
  
  private func submoduleList(manager: some SubmoduleManagement) -> some View
  {
    SubmoduleList(model: models.submoduleModel,
                  selection: $coordinator.submoduleSelection)
  }
}

#if DEBUG
// For some reason NullFileStatusDetection isn't visible, even though
// calling this NullFileStatusDetection is an "invalid redeclaration"
private class NFSD: EmptyFileStatusDetection {}

#Preview
{
  let brancher = BranchListPreview.Brancher(localBranches: [
    "master",
    "feature/things",
    "someWork",
  ].map { .init(name: $0) })
  let manager = FakeRemoteManager(remoteNames: ["origin"])
  let publisher = NullRepositoryPublishing()
  let stasher = StashListPreview.PreviewStashing(["one", "two", "three"])
  let tagger = TagListPreview.Tagger(tagList: [
    "someWork",
    "releases/v1.0",
    "releases/v1.1",
  ].map { .init(name: $0) })
  let subManager = SubmoduleListPreview.SubmoduleManager()
  let referencer = BranchListPreview.CommitReferencer()
  let models = SidebarViewModel(brancher: brancher,
                                detector: NFSD(),
                                remoteManager: manager,
                                referencer: referencer,
                                publisher: publisher,
                                stasher: stasher,
                                submoduleManager: subManager,
                                tagger: tagger,
                                workspaceCountModel: .init())
  
  TabbedSidebar(brancher: brancher, remoteManager: manager,
                referencer: referencer, publisher: publisher,
                stasher: stasher, submoduleManager: subManager, tagger: tagger,
                models: models)
    .environmentObject(SidebarCoordinator())
    .environmentObject(BranchAccessoryStore())
}
#endif
