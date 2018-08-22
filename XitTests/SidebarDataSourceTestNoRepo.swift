import Foundation
import XCTest
@testable import Xit


class SidebarDataSourceTestNoRepo: XCTestCase
{
  class FakeRepo: FakeFileChangesRepo, RemoteManagement
  {
    let localBranch1 = FakeLocalBranch(name: "branch1")
    let localBranch2 = FakeLocalBranch(name: "branch2")
    let remoteBranch1 = FakeRemoteBranch(name: "origin1/branch1")
    let remoteBranch2 = FakeRemoteBranch(name: "origin2/branch2")
    
    let remote1 = FakeRemote()
    let remote2 = FakeRemote()
    
    override init()
    {
      self.localBranch1.trackingBranchName = remoteBranch1.name
      self.localBranch1.trackingBranch = remoteBranch1
      self.localBranch2.trackingBranchName = remoteBranch2.name
      self.localBranch2.trackingBranch = remoteBranch2
      self.remoteBranch1.remoteName = "remote1"
      self.remoteBranch2.remoteName = "remote2"
      
      super.init()
      
      remote1.name = "remote1"
      remote1.urlString = "https://example.com/repo1.git"
      
      remote2.name = "remote2"
      remote1.urlString = "https://example.com/repo2.git"
    }
    
    override func localBranch(named name: String) -> LocalBranch?
    {
      switch name {
        case "branch1":
          return localBranch1
        case "branch2":
          return localBranch2
        default:
          return nil
      }
    }
    
    func remoteNames() -> [String] { return ["origin1", "origin2" ]}

    func remote(named name: String) -> Remote?
    {
      switch name {
        case "remote1": return remote1
        case "remote2": return remote2
        default: return nil
      }
    }

    func addRemote(named name: String, url: URL) throws {}
    func deleteRemote(named name: String) throws {}
  }
  
  func testPullRequestForBranch()
  {
    let sbds = SideBarDataSource()
    let fakeRepo = FakeRepo()
    // sbds.repository isn't used in this test

    let matchPR = FakePullRequest(
          sourceBranch: "branch1",
          sourceRepo: fakeRepo.remote1.url,
          displayName: "PR1", id: "1",
          authorName: "Man1", status: .open,
          webURL: URL(string: "https://example.com/repo1"))
    let otherPR = FakePullRequest(
          sourceBranch: "branch2",
          sourceRepo: fakeRepo.remote2.url,
          displayName: "PR2", id: "2",
          authorName: "Man2", status: .open,
          webURL: URL(string: "https://example.com/repo2"))
    
    sbds.pullRequestCache = PullRequestCache(repository: fakeRepo)
    sbds.pullRequestCache.requests = [matchPR, otherPR]
    
    let commit1 = FakeCommit(parentOIDs: [], message: "", authorSig: nil,
                             committerSig: nil, email: nil, tree: nil,
                             oid: StringOID(sha: "A"))
    let branch1Selection = CommitSelection(repository: fakeRepo, commit: commit1)
    let branch1Item = LocalBranchSidebarItem(title: "branch1",
                                             selection: branch1Selection)
    
    XCTAssertEqual(sbds.pullRequest(for: branch1Item)?.id, matchPR.id)
  }
}
