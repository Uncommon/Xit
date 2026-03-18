import Foundation
import SwiftUI
import XitGit

/// Delegate that executes sidebar commands on behalf of the SwiftUI sidebar.
@MainActor
protocol SidebarCoordinatorDelegate: AnyObject
{
  func newBranch()
  func newRemote()
  func checkoutBranch(_ branch: LocalBranchRefName)
  func mergeBranch(_ branch: LocalBranchRefName)
  func renameBranch(_ branch: LocalBranchRefName)
  func deleteBranch(_ branch: LocalBranchRefName)
  func createTrackingBranch(_ branch: RemoteBranchRefName)
  func mergeRemoteBranch(_ branch: RemoteBranchRefName)
  func renameRemote(_ remote: String)
  func editRemote(_ remote: String)
  func deleteRemote(_ remote: String)
  func copyRemoteURL(_ remote: String)
  func deleteTag(_ tag: TagRefName)
  func popStash(_ stashID: GitOID)
  func applyStash(_ stashID: GitOID)
  func dropStash(_ stashID: GitOID)
  func showSubmoduleInFinder(_ name: String)
  func updateSubmodule(_ name: String)
  func refreshSidebar()
}

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

  /// Delegate supplied by `TabbedSidebarController`.
  weak var delegate: (any SidebarCoordinatorDelegate)?

  /// Convenience wrappers used by SwiftUI views instead of calling closures
  /// directly. Keeping these methods centralized makes later validation or
  /// enablement changes easier.
  func newBranch() { delegate?.newBranch() }
  func newRemote() { delegate?.newRemote() }
  func checkoutBranch(_ branch: LocalBranchRefName) { delegate?.checkoutBranch(branch) }
  func mergeBranch(_ branch: LocalBranchRefName) { delegate?.mergeBranch(branch) }
  func renameBranch(_ branch: LocalBranchRefName) { delegate?.renameBranch(branch) }
  func deleteBranch(_ branch: LocalBranchRefName) { delegate?.deleteBranch(branch) }
  func createTrackingBranch(_ branch: RemoteBranchRefName)
  { delegate?.createTrackingBranch(branch) }
  func mergeRemoteBranch(_ branch: RemoteBranchRefName)
  { delegate?.mergeRemoteBranch(branch) }
  func renameRemote(_ remote: String) { delegate?.renameRemote(remote) }
  func editRemote(_ remote: String) { delegate?.editRemote(remote) }
  func deleteRemote(_ remote: String) { delegate?.deleteRemote(remote) }
  func copyRemoteURL(_ remote: String) { delegate?.copyRemoteURL(remote) }
  func deleteTag(_ tag: TagRefName) { delegate?.deleteTag(tag) }

  /// Presents the annotated-tag popover.
  func showTagInfo(_ presentation: TagInfoModel)
  {
    presentedTagInfo = presentation
  }

  func dismissTagInfo()
  {
    presentedTagInfo = nil
  }

  func popStash(_ stashID: GitOID) { delegate?.popStash(stashID) }
  func applyStash(_ stashID: GitOID) { delegate?.applyStash(stashID) }
  func dropStash(_ stashID: GitOID) { delegate?.dropStash(stashID) }
  func showSubmoduleInFinder(_ name: String) { delegate?.showSubmoduleInFinder(name) }
  func updateSubmodule(_ name: String) { delegate?.updateSubmodule(name) }

  /// Re-runs the sidebar models' refresh logic.
  func refresh() { delegate?.refreshSidebar() }
}
