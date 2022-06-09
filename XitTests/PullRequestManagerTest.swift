import Foundation
import XCTest
@testable import Xit


@MainActor
class PullRequestManagerTest: XCTestCase
{
  let fakeRepo = FakeRepo()
  var model: SidebarDataModel!

  @MainActor
  override func setUp()
  {
    super.setUp()
    
    model = SidebarDataModel(repository: fakeRepo)
    model.reload()
  }
  
  func testPullRequestForBranch()
  {
    let prManager = SidebarPRManager(model: model, outline: nil)
    let matchPR = FakePullRequest(
          serviceID: .init(),
          availableActions: [],
          sourceBranch: "refs/heads/branch1",
          sourceRepo: fakeRepo.remote1.url,
          displayName: "PR1", id: "1",
          authorName: "Man1", status: .open,
          webURL: URL(string: "https://example.com/repo1"))
    let otherPR = FakePullRequest(
          serviceID: .init(),
          availableActions: [],
          sourceBranch: "refs/heads/branch2",
          sourceRepo: fakeRepo.remote2.url,
          displayName: "PR2", id: "2",
          authorName: "Man2", status: .open,
          webURL: URL(string: "https://example.com/repo2"))
    
    prManager.pullRequestCache = PullRequestCache(repository: fakeRepo)
    prManager.pullRequestCache.requests = [matchPR, otherPR]
    
    let commit1 = StringCommit(parentOIDs: [], message: "", authorSig: nil,
                               committerSig: nil, id: "A", tree: nil)
    let branch1Selection = CommitSelection(repository: fakeRepo, commit: commit1)
    let branch1Item = LocalBranchSidebarItem(title: "branch1",
                                             selection: branch1Selection)
    
    XCTAssertEqual(prManager.pullRequest(for: branch1Item)?.id, matchPR.id)
  }
}
