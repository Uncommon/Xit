import Foundation

/// Common refresh surface for the cached sidebar models owned by the host controller.
@MainActor
protocol SidebarViewModelRefreshing: AnyObject
{
  func refresh()
}

/// Cached view model for the entire sidebar.
///
/// This bundles the per-tab list models so the host controller can retain and
/// refresh them independently of the SwiftUI view lifecycle.
@MainActor
final class SidebarViewModel<Brancher, Manager, Referencer, Stasher, Tagger, SubManager>
  : SidebarViewModelRefreshing
  where Brancher: Branching, Manager: RemoteManagement,
        Referencer: CommitReferencing,
        Stasher: Stashing, Tagger: Tagging,
        SubManager: SubmoduleManagement,
        Brancher.LocalBranch == Referencer.LocalBranch
{
  let branchModel: BranchListViewModel<Brancher, Referencer>
  let remoteModel: RemoteListViewModel<Manager, Brancher>
  let tagModel: TagListViewModel<Tagger>
  let stashModel: StashListViewModel<Stasher>
  let submoduleModel: SubmoduleListModel<SubManager>

  init(brancher: Brancher,
       detector: any FileStatusDetection,
       remoteManager: Manager,
       referencer: Referencer,
       publisher: any RepositoryPublishing,
       stasher: Stasher,
       submoduleManager: SubManager,
       tagger: Tagger,
       workspaceCountModel: WorkspaceStatusCountModel)
  {
    self.branchModel = .init(brancher: brancher,
                             referencer: referencer,
                             detector: detector,
                             publisher: publisher,
                             workspaceCountModel: workspaceCountModel)
    self.remoteModel = .init(manager: remoteManager,
                             brancher: brancher,
                             publisher: publisher)
    self.tagModel = .init(tagger: tagger, publisher: publisher)
    self.stashModel = .init(stasher: stasher, publisher: publisher)
    self.submoduleModel = .init(manager: submoduleManager, publisher: publisher)
  }

  func refresh()
  {
    branchModel.updateBranchList()
    remoteModel.updateList()
    tagModel.setTagHierarchy()
    stashModel.filterChanged(stashModel.filter)
    submoduleModel.updateList()
  }
}
