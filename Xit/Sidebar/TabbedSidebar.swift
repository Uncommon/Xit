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
      case .local: ›"Local"
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

struct SidebarViewModel<Brancher, Manager, Referencer, Stasher, Tagger, SubManager>
  where Brancher: Branching, Manager: RemoteManagement,
        Referencer: CommitReferencing,
        Stasher: Stashing, Tagger: Tagging,
        SubManager: SubmoduleManagement,
        Brancher.LocalBranch == Referencer.LocalBranch
{
  let brachModel: BranchListViewModel<Brancher, Referencer>
  let remoteModel: RemoteListViewModel<Manager, Brancher>
  let tagModel: TagListViewModel<Tagger>
  let stashModel: StashListViewModel<Stasher>
  let submoduleModel: SubmoduleListModel<SubManager>
}


struct TabbedSidebar<Brancher, Manager, Referencer, Stasher, Tagger, SubManager>
  : View
  where Brancher: Branching, Manager: RemoteManagement,
        Referencer: CommitReferencing,
        Stasher: Stashing, Tagger: Tagging, SubManager: SubmoduleManagement,
        Brancher.LocalBranch == Referencer.LocalBranch
{
  @State var tab: SidebarTab = .local(modified: false)
  @State var expandedBranches: Set<String> = []
  @State var expandedRemotes: Set<String> = []
  @State var expandedTags: Set<String> = []

  @Binding var repoSelection: (any RepositorySelection)?
  @State private var selectedBranch: String? = nil
  @State private var selectedTag: String? = nil
  @State private var selectedStash: GitOID? = nil
  @State private var selectedSubmodule: String? = nil

  // These are separate for testing/preview convenience
  let brancher: Brancher
  let detector: any FileStatusDetection
  let remoteManager: Manager
  let referencer: Referencer
  let publisher: any RepositoryPublishing
  let stasher: Stasher
  let submobuleManager: SubManager
  let tagger: Tagger
  
  @State var model: SidebarViewModel<Brancher, Manager, Referencer, Stasher,
                                     Tagger, SubManager>
  
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
  }

  init(brancher: Brancher,
       detector: any FileStatusDetection,
       remoteManager: Manager,
       referencer: Referencer,
       publisher: any RepositoryPublishing,
       stasher: Stasher,
       submoduleManager: SubManager,
       tagger: Tagger,
       selection: Binding<(any RepositorySelection)?>)
  {
    self.brancher = brancher
    self.detector = detector
    self.remoteManager = remoteManager
    self.referencer = referencer
    self.publisher = publisher
    self.stasher = stasher
    self.submobuleManager = submoduleManager
    self.tagger = tagger
    self._repoSelection = selection
    self.model = .init(
        brachModel: .init(brancher: brancher,
                          referencer: referencer,
                          detector: detector,
                          publisher: publisher),
        remoteModel: .init(manager: remoteManager, brancher: brancher),
        tagModel: .init(tagger: tagger, publisher: publisher),
        stashModel: .init(stasher: stasher, publisher: publisher),
        submoduleModel: .init(manager: submobuleManager, publisher: publisher))
  }

  private func branchList() -> some View
  {
    BranchList(model: model.brachModel,
               brancher: brancher,
               referencer: referencer,
               accessorizer: .empty,
               selection: $selectedBranch,
               expandedItems: $expandedBranches)
      .onChange(of: selectedBranch) {
        guard let selectedBranch,
              let repo = brancher as? any FileChangesRepo
        else {
          repoSelection = nil
          return
        }
        if selectedBranch.isEmpty {
          repoSelection = StagingSelection(repository: repo, amending: false)
        }
        else if let refName = LocalBranchRefName(selectedBranch),
                let branch = brancher.localBranch(named: refName),
                let commit = branch.targetCommit {
          repoSelection = CommitSelection(repository: repo, commit: commit)
        }
        else {
          repoSelection = nil
        }
      }
  }
  
  private func remoteList() -> some View
  {
    RemoteList(model: model.remoteModel,
               manager: remoteManager,
               brancher: brancher,
               accessorizer: .empty,
               selection: $selectedBranch,
               expandedItems: $expandedRemotes)
      .onChange(of: selectedBranch) {
        
      }
  }

  // These views need generic wrappers because the list views are generic
  private func tagList(tagger: some Tagging,
                       publisher: some RepositoryPublishing) -> some View
  {
    TagList(model: model.tagModel,
            selection: $selectedTag,
            expandedItems: $expandedTags)
      .onChange(of: selectedTag) {
        if let selectedTag,
           let tag = tagger.tag(named: selectedTag),
           let commit = tag.commit,
           let repo = tagger as? any FileChangesRepo {
          repoSelection = CommitSelection(repository: repo, commit: commit)
        }
        else {
          repoSelection = nil
        }
      }
  }

  private func stashList(publisher: some RepositoryPublishing) -> some View
  {
    StashList(model: model.stashModel,
              stasher: stasher,
              publisher: publisher,
              selection: $selectedStash)
      .onChange(of: selectedStash) {
        if let selectedStash,
           let index = stasher.findStashIndex(selectedStash),
           let repo = stasher as? (any FileChangesRepo & Stashing) {
          repoSelection = StashSelection(repository: repo, index: UInt(index))
        }
        else {
          repoSelection = nil
        }
      }
  }
  
  private func submoduleList(manager: some SubmoduleManagement) -> some View
  {
    SubmoduleList(model: model.submoduleModel,
                  selection: $selectedSubmodule)
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
  
  TabbedSidebar(brancher: brancher, detector: NFSD(), remoteManager: manager,
                referencer: referencer, publisher: publisher,
                stasher: stasher, submoduleManager: subManager, tagger: tagger,
                selection: .constant(nil))
}
#endif
