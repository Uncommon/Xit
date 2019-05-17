import Foundation
import XCTest
@testable import Xit


class SidebarDataSourceTestNoRepo: XCTestCase
{
  class FakeRepo: FakeFileChangesRepo, TaskManagement
  {
    let localBranch1 = FakeLocalBranch(name: "branch1")
    let localBranch2 = FakeLocalBranch(name: "branch2")
    let remoteBranch1 = FakeRemoteBranch(name: "origin1/branch1")
    let remoteBranch2 = FakeRemoteBranch(name: "origin2/branch2")
    
    let remote1 = FakeRemote()
    let remote2 = FakeRemote()
    
    let queue = TaskQueue(id: "test")
    var isWriting: Bool { return false }
    
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
  }
  
  func testPullRequestForBranch()
  {
    let sbds = SideBarDataSource()
    let fakeRepo = FakeRepo()
    
    sbds.repository = fakeRepo

    let service = FakePRService()
    let matchPR = FakePullRequest(
          service: service,
          availableActions: [],
          sourceBranch: "branch1",
          sourceRepo: fakeRepo.remote1.url,
          displayName: "PR1", id: "1",
          authorName: "Man1", status: .open,
          webURL: URL(string: "https://example.com/repo1"))
    let otherPR = FakePullRequest(
          service: service,
          availableActions: [],
          sourceBranch: "branch2",
          sourceRepo: fakeRepo.remote2.url,
          displayName: "PR2", id: "2",
          authorName: "Man2", status: .open,
          webURL: URL(string: "https://example.com/repo2"))
    guard let prManager = sbds.pullRequestManager
    else {
      XCTFail("No pull request manager")
      return
    }
    
    prManager.pullRequestCache = PullRequestCache(repository: fakeRepo)
    prManager.pullRequestCache.requests = [matchPR, otherPR]
    
    let commit1 = FakeCommit(parentOIDs: [], message: "", authorSig: nil,
                             committerSig: nil, email: nil, tree: nil,
                             oid: StringOID(sha: "A"))
    let branch1Selection = CommitSelection(repository: fakeRepo, commit: commit1)
    let branch1Item = LocalBranchSidebarItem(title: "branch1",
                                             selection: branch1Selection)
    
    XCTAssertEqual(prManager.pullRequest(for: branch1Item)?.id, matchPR.id)
  }
}

extension SidebarDataSourceTestNoRepo.FakeRepo: Branching
{
  var localBranches: AnySequence<LocalBranch>
  {
    let array: [LocalBranch] = [localBranch1, localBranch2]
    return AnySequence(array)
  }
  
  var remoteBranches: AnySequence<RemoteBranch>
  {
    let array: [RemoteBranch] = [remoteBranch1, remoteBranch2]
    return AnySequence(array)
  }
  
  func createBranch(named name: String, target: String) throws -> LocalBranch?
  { return nil }
  func remoteBranch(named name: String) -> RemoteBranch?
  { return nil }
  func localBranch(tracking remoteBranch: RemoteBranch) -> LocalBranch?
  { return nil }
  func localTrackingBranch(forBranchRef branch: String) -> LocalBranch?
  { return nil }
}

extension SidebarDataSourceTestNoRepo.FakeRepo: CommitStorage
{
  func oid(forSHA sha: String) -> OID? { return nil }
  func commit(forSHA sha: String) -> Commit? { return nil }
  func commit(forOID oid: OID) -> Commit? { return nil }
  func walker() -> RevWalk? { return nil }
}

extension SidebarDataSourceTestNoRepo.FakeRepo: Stashing
{
  var stashes: AnyCollection<Stash> { return AnyCollection([]) }
  func stash(index: UInt, message: String?) -> Stash { return FakeStash() }
  func popStash(index: UInt) throws {}
  func applyStash(index: UInt) throws {}
  func dropStash(index: UInt) throws {}
  func commitForStash(at index: UInt) -> Commit? { return nil }
  func saveStash(name: String?, keepIndex: Bool,
                 includeUntracked: Bool, includeIgnored: Bool) throws {}
}

extension SidebarDataSourceTestNoRepo.FakeRepo: SubmoduleManagement
{
  func submodules() -> [Submodule] { return [] }
  func addSubmodule(path: String, url: String) throws {}
}

extension SidebarDataSourceTestNoRepo.FakeRepo: RemoteManagement
{
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
