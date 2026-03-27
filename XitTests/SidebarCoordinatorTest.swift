import Foundation
import SwiftUI
import Testing
@testable import Xit

private typealias SidebarTestReferencer =
    FakeCommitReferencing<FakeCommit, FakeTree, TestLocalBranch, TestRemoteBranch>

@MainActor
private final class SidebarCoordinatorDelegateSpy: SidebarCoordinatorDelegate
{
  enum Event: Equatable
  {
    case newBranch
    case newRemote
    case checkout(LocalBranchRefName)
    case merge(LocalBranchRefName)
    case renameBranch(LocalBranchRefName)
    case deleteBranch(LocalBranchRefName)
    case createTracking(RemoteBranchRefName)
    case mergeRemote(RemoteBranchRefName)
    case renameRemote(String)
    case editRemote(String)
    case deleteRemote(String)
    case copyRemoteURL(String)
    case deleteTag(TagRefName)
    case popStash(GitOID)
    case applyStash(GitOID)
    case dropStash(GitOID)
    case showSubmodule(String)
    case updateSubmodule(String)
    case refresh
  }

  var events: [Event] = []

  func newBranch()
  {
    events.append(.newBranch)
  }

  func newRemote()
  {
    events.append(.newRemote)
  }

  func checkoutBranch(_ branch: LocalBranchRefName)
  {
    events.append(.checkout(branch))
  }

  func mergeBranch(_ branch: LocalBranchRefName)
  {
    events.append(.merge(branch))
  }

  func renameBranch(_ branch: LocalBranchRefName)
  {
    events.append(.renameBranch(branch))
  }

  func deleteBranch(_ branch: LocalBranchRefName)
  {
    events.append(.deleteBranch(branch))
  }

  func createTrackingBranch(_ branch: RemoteBranchRefName)
  {
    events.append(.createTracking(branch))
  }

  func mergeRemoteBranch(_ branch: RemoteBranchRefName)
  {
    events.append(.mergeRemote(branch))
  }

  func renameRemote(_ remote: String)
  {
    events.append(.renameRemote(remote))
  }

  func editRemote(_ remote: String)
  {
    events.append(.editRemote(remote))
  }

  func deleteRemote(_ remote: String)
  {
    events.append(.deleteRemote(remote))
  }

  func copyRemoteURL(_ remote: String)
  {
    events.append(.copyRemoteURL(remote))
  }

  func deleteTag(_ tag: TagRefName)
  {
    events.append(.deleteTag(tag))
  }

  func popStash(_ stashID: GitOID)
  {
    events.append(.popStash(stashID))
  }

  func applyStash(_ stashID: GitOID)
  {
    events.append(.applyStash(stashID))
  }

  func dropStash(_ stashID: GitOID)
  {
    events.append(.dropStash(stashID))
  }

  func showSubmoduleInFinder(_ name: String)
  {
    events.append(.showSubmodule(name))
  }

  func updateSubmodule(_ name: String)
  {
    events.append(.updateSubmodule(name))
  }

  func refreshSidebar()
  {
    events.append(.refresh)
  }
}

@MainActor
struct SidebarCoordinatorTest
{
  @Test
  func branchRemoteCommandsDispatch() throws
  {
    let coordinator = SidebarCoordinator()
    let delegate = SidebarCoordinatorDelegateSpy()
    let branch = try #require(LocalBranchRefName.named("main"))
    let remoteBranch = try #require(RemoteBranchRefName(remote: "origin",
                                                        branch: "main"))

    coordinator.delegate = delegate

    coordinator.newBranch()
    coordinator.newRemote()
    coordinator.checkoutBranch(branch)
    coordinator.mergeBranch(branch)
    coordinator.renameBranch(branch)
    coordinator.deleteBranch(branch)
    coordinator.createTrackingBranch(remoteBranch)
    coordinator.mergeRemoteBranch(remoteBranch)
    coordinator.renameRemote("origin")
    coordinator.editRemote("origin")
    coordinator.deleteRemote("origin")
    coordinator.copyRemoteURL("origin")

    #expect(delegate.events == [
      .newBranch,
      .newRemote,
      .checkout(branch),
      .merge(branch),
      .renameBranch(branch),
      .deleteBranch(branch),
      .createTracking(remoteBranch),
      .mergeRemote(remoteBranch),
      .renameRemote("origin"),
      .editRemote("origin"),
      .deleteRemote("origin"),
      .copyRemoteURL("origin"),
    ])
  }

  @Test
  func tagStashSubmoduleCommandsDispatch() throws
  {
    let coordinator = SidebarCoordinator()
    let delegate = SidebarCoordinatorDelegateSpy()
    let tag = try #require(TagRefName.named("v1.0"))
    let stashID = GitOID.fakeDefault()

    coordinator.delegate = delegate

    coordinator.deleteTag(tag)
    coordinator.popStash(stashID)
    coordinator.applyStash(stashID)
    coordinator.dropStash(stashID)
    coordinator.showSubmoduleInFinder("Dependencies/Core")
    coordinator.updateSubmodule("Dependencies/Core")
    coordinator.refresh()

    #expect(delegate.events == [
      .deleteTag(tag),
      .popStash(stashID),
      .applyStash(stashID),
      .dropStash(stashID),
      .showSubmodule("Dependencies/Core"),
      .updateSubmodule("Dependencies/Core"),
      .refresh,
    ])
  }

  @Test
  func remoteTagPresentationStateUpdates() throws
  {
    let coordinator = SidebarCoordinator()
    let remoteBranch = try #require(RemoteBranchRefName(remote: "origin",
                                                        branch: "main"))

    coordinator.activeTab = .remote
    coordinator.remoteSelection = .branch(ref: remoteBranch)
    coordinator.showTagInfo(.init(tagName: "v1.0",
                                  authorName: "Author",
                                  authorEmail: "author@example.com",
                                  date: .init(timeIntervalSinceReferenceDate: 0),
                                  message: "annotated"))

    #expect(coordinator.activeTab == .remote)
    #expect(coordinator.remoteSelection == .branch(ref: remoteBranch))
    #expect(coordinator.presentedTagInfo?.tagName == "v1.0")

    coordinator.dismissTagInfo()

    #expect(coordinator.presentedTagInfo == nil)
  }

  @Test
  func sidebarRefreshUpdatesCachedLists() throws
  {
    let current = try #require(LocalBranchRefName.named("main"))
    let brancher = TestBrancher(localBranches: [.init(name: "main")],
                                remoteBranches: [
                                        .init(remoteName: "origin", name: "main")
                                       ],
                                currentBranch: current)
    let remoteManager = TestRemoteManager(remoteNames: ["origin"])
    let referencer = SidebarTestReferencer()
    let tagger = TestTagger(tagList: [
      .init(name: try #require(TagRefName.named("v1.0")))
    ])
    let stasher = TestStasher(stashes: [TestStash(message: "WIP")])
    let submoduleManager = TestSubmoduleManager(submodules: [
      TestSubmodule(name: "Core",
                    path: "Dependencies/Core",
                    url: URL(string: "https://example.com/core.git"))
    ])
    let models = SidebarViewModel(brancher: brancher,
                                  detector: TestFileStatusDetector(),
                                  remoteManager: remoteManager,
                                  referencer: referencer,
                                  publisher: TestRepositoryPublisher(),
                                  stasher: stasher,
                                  submoduleManager: submoduleManager,
                                  tagger: tagger,
                                  workspaceCountModel: .init())

    try #require(models.branchModel.branches.count == 1)
    try #require(models.remoteModel.remotes.map(\.name) == ["origin"])
    try #require(models.tagModel.tags.count == 1)
    try #require(models.stashModel.stashes.count == 1)
    try #require(models.submoduleModel.submodules.count == 1)

    brancher.localBranchArray.append(.init(name: "feature"))
    remoteManager.remoteNameList = ["origin", "upstream"]
    brancher.remoteBranchArray = [
      .init(remoteName: "origin", name: "main"),
      .init(remoteName: "upstream", name: "develop"),
    ]
    tagger.tagList.append(.init(name: try #require(TagRefName.named("v2.0"))))
    stasher.stashArray.append(TestStash(message: "Next"))
    submoduleManager.submoduleList.append(
      TestSubmodule(name: "UI",
                    path: "Dependencies/UI",
                    url: URL(string: "https://example.com/ui.git")))

    models.refresh()

    #expect(models.branchModel.branches.count == 2)
    #expect(models.remoteModel.remotes.map(\.name) == ["origin", "upstream"])
    #expect(models.tagModel.tags.count == 2)
    #expect(models.stashModel.stashes.count == 2)
    #expect(models.submoduleModel.submodules.count == 2)
  }

  @Test
  func branchSelectionHelpersRespectCurrent() throws
  {
    let current = try #require(LocalBranchRefName.named("main"))
    let feature = try #require(LocalBranchRefName.named("feature"))
    let brancher = TestBrancher(
        localBranches: [.init(name: "main"), .init(name: "feature")],
        currentBranch: current)
    let referencer = SidebarTestReferencer()
    let model = BranchListViewModel(brancher: brancher,
                                    referencer: referencer,
                                    detector: TestFileStatusDetector(),
                                    publisher: TestRepositoryPublisher(),
                                    workspaceCountModel: .init())
    let list = BranchList(model: model,
                          brancher: brancher,
                          referencer: referencer,
                          selection: .constant(.branch(feature)),
                          expandedItems: .constant(Set<String>()))

    #expect(list.selectedBranch == feature)
    #expect(list.branchRef(from: [.branch(feature)]) == feature)
    #expect(list.branchRef(from: [.staging]) == nil)
    #expect(!list.canEditSelection(nil))
    #expect(!list.canEditSelection(current))
    #expect(list.canEditSelection(feature))
    #expect(!list.canMergeSelection(nil))
    #expect(!list.canMergeSelection(current))
    #expect(list.canMergeSelection(feature))
  }

  @Test
  func remoteSelectionTreatsOnlyRemoteRows() throws
  {
    let manager = TestRemoteManager(remoteNames: ["origin"])
    let brancher = TestBrancher(remoteBranches: [
      .init(remoteName: "origin", name: "main")
    ])
    let remoteBranch = try #require(RemoteBranchRefName(remote: "origin",
                                                        branch: "main"))
    let remoteList = RemoteList(
        model: .init(manager: manager,
                     brancher: brancher,
                     publisher: TestRepositoryPublisher()),
        selection: .constant(.remote(name: "origin")),
        expandedItems: .constant(Set<String>()))
    let branchList = RemoteList(
        model: .init(manager: manager,
                     brancher: brancher,
                     publisher: TestRepositoryPublisher()),
        selection: .constant(.branch(ref: remoteBranch)),
        expandedItems: .constant(Set<String>()))

    #expect(remoteList.selectedRemote == "origin")
    #expect(branchList.selectedRemote == nil)
  }
}

@MainActor
struct BranchListTest
{
  @Test
  func trackingIndicatorUsesGraphStatus() throws
  {
    let trackingBranch = TestRemoteBranch(remoteName: "origin", name: "main")
    let branch = BranchListItem(refName: try #require(LocalBranchRefName.named("main")),
                                trackingRefName: trackingBranch.referenceName,
                                isCurrent: false,
                                graphStatus: .init(ahead: 0, behind: 1))

    #expect(branch.trackingIndicator
              == BranchTrackingIndicator.statusBadge("↓1"))
  }

  @Test
  func trackingIndicatorShowsNetworkAtZero() throws
  {
    let trackingBranch = TestRemoteBranch(remoteName: "origin", name: "main")
    let branch = BranchListItem(refName: try #require(LocalBranchRefName.named("main")),
                                trackingRefName: trackingBranch.referenceName,
                                isCurrent: false,
                                graphStatus: .zero)

    #expect(branch.trackingIndicator == BranchTrackingIndicator.network)
  }

  @Test
  func trackingIndicatorAbsentWithoutTracking() throws
  {
    let branch = BranchListItem(refName: try #require(LocalBranchRefName.named("main")),
                                trackingRefName: nil,
                                isCurrent: false,
                                graphStatus: .init(ahead: 3, behind: 2))

    #expect(branch.trackingIndicator == BranchTrackingIndicator.none)
  }

  @Test
  func branchSelectionValueOnlyOnBranches() throws
  {
    let feature = try #require(LocalBranchRefName.named("feature"))
    let subfeature = try #require(LocalBranchRefName.named("feature/subfeature"))
    let items = [
      BranchListItem(refName: feature,
                     trackingRefName: nil,
                     isCurrent: false,
                     graphStatus: .zero),
      BranchListItem(refName: subfeature,
                     trackingRefName: nil,
                     isCurrent: false,
                     graphStatus: .zero),
    ]
    let tree = PathTreeNode.makeHierarchy(from: items, prefix: RefPrefixes.heads)
    let brancher = TestBrancher(localBranches: [.init(name: "feature"),
                                                .init(name: "feature/subfeature")])
    let referencer = SidebarTestReferencer()
    let list = BranchList(model: .init(brancher: brancher,
                                       referencer: referencer,
                                       detector: TestFileStatusDetector(),
                                       publisher: TestRepositoryPublisher(),
                                       workspaceCountModel: .init()),
                          brancher: brancher,
                          referencer: referencer,
                          selection: .constant(nil),
                          expandedItems: .constant(Set<String>()))

    let featureNode =
        try #require(tree.first(where: { $0.path == "refs/heads/feature" }))
    let subfeatureNode =
        try #require(featureNode.children?
          .first(where: { $0.path == "refs/heads/feature/subfeature" }))
    let folderTree = PathTreeNode.makeHierarchy(
      from: [BranchListItem(refName: try #require(LocalBranchRefName.named("topic/item")),
                            trackingRefName: nil,
                            isCurrent: false,
                            graphStatus: .zero)],
      prefix: RefPrefixes.heads)
    let folderNode =
        try #require(folderTree.first(where: { $0.path == "refs/heads/topic" }))

    #expect(list.selectionValue(for: featureNode) == .branch(feature))
    #expect(list.selectionValue(for: subfeatureNode) == .branch(subfeature))
    #expect(list.selectionValue(for: folderNode) == nil)
  }

  @Test
  func remoteSelectionValueOnlyOnBranches() throws
  {
    let remoteBranch = try #require(RemoteBranchRefName(remote: "origin",
                                                        branch: "feature"))
    let nestedRemoteBranch = try #require(RemoteBranchRefName(remote: "origin",
                                                              branch: "feature/subfeature"))
    let manager = TestRemoteManager(remoteNames: ["origin"])
    let brancher = TestBrancher(remoteBranches: [
      .init(remoteName: "origin", name: "feature"),
      .init(remoteName: "origin", name: "feature/subfeature"),
    ])
    let list = RemoteList(model: .init(manager: manager,
                                       brancher: brancher,
                                       publisher: TestRepositoryPublisher()),
                          selection: .constant(nil),
                          expandedItems: .constant(Set<String>()))
    let remoteNode = try #require(list.treeItems.first(where: { $0.path == "origin" }))
    let featureNode =
        try #require(remoteNode.children?.first(where: { $0.path == "origin/feature" }))
    let nestedNode = try #require(featureNode.children?
      .first(where: { $0.path == "origin/feature/subfeature" }))
    let folderBrancher = TestBrancher(remoteBranches: [
      .init(remoteName: "origin", name: "topic/item"),
    ])
    let folderList = RemoteList(model: .init(manager: manager,
                                             brancher: folderBrancher,
                                             publisher: TestRepositoryPublisher()),
                                selection: .constant(nil),
                                expandedItems: .constant(Set<String>()))
    let folderRemoteNode =
        try #require(folderList.treeItems.first(where: { $0.path == "origin" }))
    let folderNode =
        try #require(folderRemoteNode.children?.first(where: { $0.path == "origin/topic" }))

    #expect(remoteNode.item == .remote("origin"))
    #expect(featureNode.item == .branch(remoteBranch))
    #expect(nestedNode.item == .branch(nestedRemoteBranch))
    #expect(folderNode.item == nil)
  }
}
