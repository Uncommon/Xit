import Foundation
import SwiftUI
import Testing
@testable import Xit

private final class SidebarTestBrancher: EmptyBranching, EmptyRepositoryPublishing
{
  typealias LocalBranch = FakeLocalBranch
  typealias RemoteBranch = FakeRemoteBranch

  var localBranchArray: [LocalBranch]
  var remoteBranchArray: [RemoteBranch]
  var localBranches: AnySequence<LocalBranch> { .init(localBranchArray) }
  var remoteBranches: AnySequence<RemoteBranch> { .init(remoteBranchArray) }
  var currentBranch: LocalBranchRefName?

  init(localBranches: [LocalBranch] = [],
       remoteBranches: [RemoteBranch] = [],
       currentBranch: LocalBranchRefName? = nil)
  {
    self.localBranchArray = localBranches
    self.remoteBranchArray = remoteBranches
    self.currentBranch = currentBranch
  }

  func localBranch(named refName: LocalBranchRefName) -> LocalBranch?
  {
    localBranchArray.first { $0.referenceName == refName }
  }

  func remoteBranch(named name: String) -> RemoteBranch?
  {
    remoteBranchArray.first { $0.referenceName.name == name }
  }

  func remoteBranch(named name: String, remote: String) -> RemoteBranch?
  {
    remoteBranchArray.first {
      $0.referenceName.name == name && $0.remoteName == remote
    }
  }
}

private final class SidebarTestFileStatusDetector: EmptyFileStatusDetection {}
private typealias SidebarTestReferencer =
    FakeCommitReferencing<NullCommit, FakeTree, FakeLocalBranch, FakeRemoteBranch>

@MainActor
struct SidebarCoordinatorTest
{
  @Test
  func branchActionsDispatch() throws
  {
    let coordinator = SidebarCoordinator()
    let branch = try #require(LocalBranchRefName.named("main"))
    var checkedOut: LocalBranchRefName?
    var merged: LocalBranchRefName?

    coordinator.checkoutBranchAction = { checkedOut = $0 }
    coordinator.mergeBranchAction = { merged = $0 }

    coordinator.checkoutBranch(branch)
    coordinator.mergeBranch(branch)

    #expect(checkedOut == branch)
    #expect(merged == branch)
  }

  @Test
  func remoteAndTagPresentationStateUpdates() throws
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
  func stashAndSubmoduleActionsDispatch() throws
  {
    let coordinator = SidebarCoordinator()
    let stashID = GitOID.fakeDefault()
    var popped: GitOID?
    var updatedSubmodule: String?

    coordinator.popStashAction = { popped = $0 }
    coordinator.updateSubmoduleAction = { updatedSubmodule = $0 }

    coordinator.popStash(stashID)
    coordinator.updateSubmodule("Dependencies/Core")

    #expect(popped == stashID)
    #expect(updatedSubmodule == "Dependencies/Core")
  }

  @Test
  func remoteActionsTagDeletionAndRefreshDispatch() throws
  {
    let coordinator = SidebarCoordinator()
    let remoteBranch = try #require(RemoteBranchRefName(remote: "origin",
                                                        branch: "main"))
    let tag = try #require(TagRefName.named("v1.0"))
    var createdTracking: RemoteBranchRefName?
    var mergedRemote: RemoteBranchRefName?
    var renamedRemote: String?
    var editedRemote: String?
    var deletedRemote: String?
    var copiedRemote: String?
    var deletedTag: TagRefName?
    var refreshed = false

    coordinator.createTrackingBranchAction = { createdTracking = $0 }
    coordinator.mergeRemoteBranchAction = { mergedRemote = $0 }
    coordinator.renameRemoteAction = { renamedRemote = $0 }
    coordinator.editRemoteAction = { editedRemote = $0 }
    coordinator.deleteRemoteAction = { deletedRemote = $0 }
    coordinator.copyRemoteURLAction = { copiedRemote = $0 }
    coordinator.deleteTagAction = { deletedTag = $0 }
    coordinator.refreshAction = { refreshed = true }

    coordinator.createTrackingBranch(remoteBranch)
    coordinator.mergeRemoteBranch(remoteBranch)
    coordinator.renameRemote("origin")
    coordinator.editRemote("origin")
    coordinator.deleteRemote("origin")
    coordinator.copyRemoteURL("origin")
    coordinator.deleteTag(tag)
    coordinator.refresh()

    #expect(createdTracking == remoteBranch)
    #expect(mergedRemote == remoteBranch)
    #expect(renamedRemote == "origin")
    #expect(editedRemote == "origin")
    #expect(deletedRemote == "origin")
    #expect(copiedRemote == "origin")
    #expect(deletedTag == tag)
    #expect(refreshed)
  }

  @Test
  func branchListSelectionHelpersRespectCurrentBranch() throws
  {
    let current = try #require(LocalBranchRefName.named("main"))
    let feature = try #require(LocalBranchRefName.named("feature"))
    let brancher = SidebarTestBrancher(
        localBranches: [.init(name: "main"), .init(name: "feature")],
        currentBranch: current)
    let referencer = SidebarTestReferencer()
    let model = BranchListViewModel(brancher: brancher,
                                    referencer: referencer,
                                    detector: SidebarTestFileStatusDetector(),
                                    publisher: brancher,
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
  func remoteListSelectionOnlyTreatsRemoteRowsAsRemoteActions() throws
  {
    let manager = FakeRemoteManager(remoteNames: ["origin"])
    let brancher = FakeBrancher(remoteBranches: [
      .init(remoteName: "origin", name: "main")
    ])
    let remoteBranch = try #require(RemoteBranchRefName(remote: "origin",
                                                        branch: "main"))
    let remoteList = RemoteList(
        model: .init(manager: manager,
                     brancher: brancher,
                     publisher: NullRepositoryPublishing()),
        manager: manager,
        brancher: brancher,
        selection: .constant(.remote(name: "origin")),
        expandedItems: .constant(Set<String>()))
    let branchList = RemoteList(
        model: .init(manager: manager,
                     brancher: brancher,
                     publisher: NullRepositoryPublishing()),
        manager: manager,
        brancher: brancher,
        selection: .constant(.branch(ref: remoteBranch)),
        expandedItems: .constant(Set<String>()))

    #expect(remoteList.selectedRemote == "origin")
    #expect(branchList.selectedRemote == nil)
  }
}
