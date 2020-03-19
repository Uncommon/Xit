import Foundation
@testable import Xit

class FakeRepo: FakeFileChangesRepo
{
  let localBranch1 = FakeLocalBranch(name: "branch1")
  let localBranch2 = FakeLocalBranch(name: "branch2")
  let remoteBranch1 = FakeRemoteBranch(remoteName: "origin1", name: "branch1")
  let remoteBranch2 = FakeRemoteBranch(remoteName: "origin2", name: "branch2")
  
  let remote1 = FakeRemote()
  let remote2 = FakeRemote()
  
  var isWriting: Bool { return false }
  
  var commits: [StringOID: FakeCommit] = [:]
  
  override init()
  {
    self.remote1.name = "origin1"
    self.remote2.name = "origin2"
    self.localBranch1.trackingBranchName = remoteBranch1.name
    self.localBranch1.trackingBranch = remoteBranch1
    self.localBranch2.trackingBranchName = remoteBranch2.name
    self.localBranch2.trackingBranch = remoteBranch2
    self.remoteBranch1.remoteName = remote1.name
    self.remoteBranch2.remoteName = remote2.name
    
    super.init()
    
    let commit1 = FakeCommit(branchHead: localBranch1)
    let commit2 = FakeCommit(branchHead: localBranch2)
    let commitR1 = FakeCommit(branchHead: remoteBranch1)
    let commitR2 = FakeCommit(branchHead: remoteBranch2)

    commits[commit1.oid as! StringOID] = commit1
    commits[commit2.oid as! StringOID] = commit2
    commits[commitR1.oid as! StringOID] = commitR1
    commits[commitR2.oid as! StringOID] = commitR2

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

extension FakeRepo: Branching
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
  func rename(branch: String, to: String) throws {}
  func reset(toCommit target: Commit, mode: ResetMode) throws {}
}

extension FakeRepo: CommitStorage
{
  func oid(forSHA sha: String) -> OID? { return StringOID(sha: sha) }
  
  func commit(forSHA sha: String) -> Commit?
  {
    return commits[StringOID(sha: sha)]
  }
  
  func commit(forOID oid: OID) -> Commit?
  {
    return (oid as? StringOID).flatMap { commits[$0] }
  }
  
  func commit(message: String, amend: Bool) throws {}
  
  func walker() -> RevWalk? { return nil }
}

extension FakeRepo: Stashing
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

extension FakeRepo: SubmoduleManagement
{
  func submodules() -> [Submodule] { return [] }
  func addSubmodule(path: String, url: String) throws {}
}

extension FakeRepo: RemoteManagement
{
  func remoteNames() -> [String] { return ["origin1", "origin2" ]}
  
  func remote(named name: String) -> Remote?
  {
    switch name {
      case "origin1": return remote1
      case "origin2": return remote2
      default: return nil
    }
  }
  
  func addRemote(named name: String, url: URL) throws {}
  func deleteRemote(named name: String) throws {}
}
