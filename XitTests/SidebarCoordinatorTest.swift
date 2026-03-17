import Foundation
import Testing
@testable import Xit

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
}
