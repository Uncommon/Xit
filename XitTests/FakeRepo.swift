import Foundation
@testable import Xit

class FakeRepo: FileChangesRepo &
  EmptyCommitReferencing & EmptyFileDiffing & EmptyFileContents &
  EmptyFileStaging & EmptyFileStatusDetection
{
  typealias Commit = FakeCommit
  typealias Tag = NullTag
  typealias Tree = FakeTree
  typealias Blob = NullBlob
  typealias LocalBranch = FakeLocalBranch
  typealias RemoteBranch = FakeRemoteBranch
  typealias Blame = NullBlame

  var controller: (any RepositoryController)?

  let localBranch1 = FakeLocalBranch(name: "branch1", oid: "a")
  let localBranch2 = FakeLocalBranch(name: "branch2", oid: "b")
  let remoteBranch1 = FakeRemoteBranch(remoteName: "origin1", name: "branch1", oid: "c")
  let remoteBranch2 = FakeRemoteBranch(remoteName: "origin2", name: "branch2", oid: "d")
  
  let remote1 = FakeRemote()
  let remote2 = FakeRemote()
  
  var isWriting: Bool { return false }
  
  var commits: [GitOID: FakeCommit] = [:]

  init()
  {
    self.remote1.name = "origin1"
    self.remote2.name = "origin2"
    self.localBranch1.trackingBranchName = remoteBranch1.name
    self.localBranch1.trackingBranch = remoteBranch1
    self.localBranch2.trackingBranchName = remoteBranch2.name
    self.localBranch2.trackingBranch = remoteBranch2
    self.remoteBranch1.remoteName = remote1.name
    self.remoteBranch2.remoteName = remote2.name
    
    let commit1 = FakeCommit(branchHead: localBranch1)
    let commit2 = FakeCommit(branchHead: localBranch2)
    let commitR1 = FakeCommit(branchHead: remoteBranch1)
    let commitR2 = FakeCommit(branchHead: remoteBranch2)

    commits[commit1.id] = commit1
    commits[commit2.id] = commit2
    commits[commitR1.id] = commitR1
    commits[commitR2.id] = commitR2

    remote1.name = "remote1"
    remote1.urlString = "https://example.com/repo1.git"
    
    remote2.name = "remote2"
    remote1.urlString = "https://example.com/repo2.git"
  }
  
  func localBranch(named name: LocalBranchRefName) -> FakeLocalBranch?
  {
    switch name.name {
      case "branch1":
        return localBranch1
      case "branch2":
        return localBranch2
      default:
        return nil
    }
  }
}

extension FakeRepo: EmptyBranching
{
  var localBranches: AnySequence<FakeLocalBranch>
  {
    let array: [LocalBranch] = [localBranch1, localBranch2]
    return AnySequence(array)
  }
  
  var remoteBranches: AnySequence<FakeRemoteBranch>
  {
    let array: [RemoteBranch] = [remoteBranch1, remoteBranch2]
    return AnySequence(array)
  }
}

extension FakeRepo: EmptyCommitStorage
{
  typealias ID = GitOID
  typealias RevWalk = NullRevWalk

  func oid(forSHA sha: SHA) -> ID? { .init(sha: sha) }

  func commit(forSHA sha: SHA) -> Commit?
  {
    GitOID(sha: sha).flatMap { commits[$0] }
  }
  
  func commit(forOID oid: ID) -> Commit?
  {
    commits[oid]
  }
}

extension FakeRepo: EmptyStashing
{
  var stashes: AnyCollection<any Stash> { return AnyCollection([]) }
  func stash(index: UInt, message: String?) -> any Stash { return FakeStash() }
}

extension FakeRepo: SubmoduleManagement
{
  func submodules() -> [Submodule] { return [] }
  func addSubmodule(path: String, url: String) throws {}
}

extension FakeRepo: RemoteManagement
{
  func remoteNames() -> [String] { return ["origin1", "origin2" ]}

  func remote(named name: String) -> FakeRemote?
  {
    switch name {
      case "origin1": return remote1
      case "origin2": return remote2
      default: return nil
    }
  }

  func addRemote(named name: String, url: URL) throws {}
  func deleteRemote(named name: String) throws {}

  func push(branches: [LocalBranchRefName],
            remote: FakeRemote,
            callbacks: RemoteCallbacks) throws {}
  func fetch(remote: FakeRemote, options: FetchOptions) throws {}
  func pull(branch: any Branch,
            remote: FakeRemote,
            options: FetchOptions) throws {}
}
