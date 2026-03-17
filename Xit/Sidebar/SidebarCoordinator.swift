import Foundation
import SwiftUI

/// Sidebar selection for the local branches tab.
enum BranchListSelection: Hashable
{
  case staging
  case branch(LocalBranchRefName)
}

/// Sidebar selection for the remotes tab.
enum RemoteListSelection: Hashable
{
  case remote(name: String)
  case branch(ref: RemoteBranchRefName)
}

/// Presentation data for the tag info popover.
struct TagInfoModel: Identifiable
{
  let tagName: String
  let authorName: String
  let authorEmail: String
  let date: Date
  let message: String

  var id: String { tagName }
}

/// Central coordinator for SwiftUI sidebar state and command dispatch.
@MainActor
final class SidebarCoordinator: ObservableObject
{
  /// The active top-level sidebar tab.
  @Published var activeTab: SidebarTab = .local(modified: false)

  /// Current selection in each tab.
  @Published var branchSelection: BranchListSelection?
  @Published var remoteSelection: RemoteListSelection?
  @Published var tagSelection: TagRefName?
  @Published var stashSelection: GitOID?
  @Published var submoduleSelection: String?

  /// Expanded tree nodes for tabs that present hierarchical content.
  @Published var expandedBranches: Set<String> = []
  @Published var expandedRemotes: Set<String> = []
  @Published var expandedTags: Set<String> = []

  /// Current annotated tag popover payload, if one is being shown.
  @Published var presentedTagInfo: TagInfoModel?

  /// Command hooks supplied by `TabbedSidebarController`.
  var newBranchAction: () -> Void = {}
  var newRemoteAction: () -> Void = {}
  var checkoutBranchAction: (LocalBranchRefName) -> Void = { _ in }
  var mergeBranchAction: (LocalBranchRefName) -> Void = { _ in }
  var renameBranchAction: (LocalBranchRefName) -> Void = { _ in }
  var deleteBranchAction: (LocalBranchRefName) -> Void = { _ in }
  var createTrackingBranchAction: (RemoteBranchRefName) -> Void = { _ in }
  var mergeRemoteBranchAction: (RemoteBranchRefName) -> Void = { _ in }
  var renameRemoteAction: (String) -> Void = { _ in }
  var editRemoteAction: (String) -> Void = { _ in }
  var deleteRemoteAction: (String) -> Void = { _ in }
  var copyRemoteURLAction: (String) -> Void = { _ in }
  var deleteTagAction: (TagRefName) -> Void = { _ in }
  var popStashAction: (GitOID) -> Void = { _ in }
  var applyStashAction: (GitOID) -> Void = { _ in }
  var dropStashAction: (GitOID) -> Void = { _ in }
  var showSubmoduleInFinderAction: (String) -> Void = { _ in }
  var updateSubmoduleAction: (String) -> Void = { _ in }
  var refreshAction: () -> Void = {}

  /// Convenience wrappers used by SwiftUI views instead of calling closures
  /// directly. Keeping these methods centralized makes later validation or
  /// enablement changes easier.
  func newBranch() { newBranchAction() }
  func newRemote() { newRemoteAction() }
  func checkoutBranch(_ branch: LocalBranchRefName) { checkoutBranchAction(branch) }
  func mergeBranch(_ branch: LocalBranchRefName) { mergeBranchAction(branch) }
  func renameBranch(_ branch: LocalBranchRefName) { renameBranchAction(branch) }
  func deleteBranch(_ branch: LocalBranchRefName) { deleteBranchAction(branch) }
  func createTrackingBranch(_ branch: RemoteBranchRefName)
  { createTrackingBranchAction(branch) }
  func mergeRemoteBranch(_ branch: RemoteBranchRefName)
  { mergeRemoteBranchAction(branch) }
  func renameRemote(_ remote: String) { renameRemoteAction(remote) }
  func editRemote(_ remote: String) { editRemoteAction(remote) }
  func deleteRemote(_ remote: String) { deleteRemoteAction(remote) }
  func copyRemoteURL(_ remote: String) { copyRemoteURLAction(remote) }
  func deleteTag(_ tag: TagRefName) { deleteTagAction(tag) }

  /// Presents the annotated-tag popover.
  func showTagInfo(_ presentation: TagInfoModel)
  {
    presentedTagInfo = presentation
  }

  func dismissTagInfo()
  {
    presentedTagInfo = nil
  }

  func popStash(_ stashID: GitOID) { popStashAction(stashID) }
  func applyStash(_ stashID: GitOID) { applyStashAction(stashID) }
  func dropStash(_ stashID: GitOID) { dropStashAction(stashID) }
  func showSubmoduleInFinder(_ name: String) { showSubmoduleInFinderAction(name) }
  func updateSubmodule(_ name: String) { updateSubmoduleAction(name) }

  /// Re-runs the sidebar models' refresh logic.
  func refresh() { refreshAction() }
}
