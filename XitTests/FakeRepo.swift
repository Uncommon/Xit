import Foundation
@testable import Xit

class FakeRepo: BasicRepository
{
  var controller: (RepositoryController)? = nil

  let localBranch1 = FakeLocalBranch(name: "branch1")
  let localBranch2 = FakeLocalBranch(name: "branch2")
  let remoteBranch1 = FakeRemoteBranch(remoteName: "origin1", name: "branch1")
  let remoteBranch2 = FakeRemoteBranch(remoteName: "origin2", name: "branch2")
  
  let remote1 = FakeRemote()
  let remote2 = FakeRemote()
  
  var isWriting: Bool { return false }
  
  var commits: [StringOID: StringCommit] = [:]

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

    let commit1 = StringCommit(branchHead: localBranch1)
    let commit2 = StringCommit(branchHead: localBranch2)
    let commitR1 = StringCommit(branchHead: remoteBranch1)
    let commitR2 = StringCommit(branchHead: remoteBranch2)

    commits[commit1.id] = commit1
    commits[commit2.id] = commit2
    commits[commitR1.id] = commitR1
    commits[commitR2.id] = commitR2

    remote1.name = "remote1"
    remote1.urlString = "https://example.com/repo1.git"
    
    remote2.name = "remote2"
    remote1.urlString = "https://example.com/repo2.git"
  }
  
  func localBranch(named name: String) -> FakeLocalBranch?
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

extension FakeRepo: EmptyBranching
{
  var currentBranch: String? { nil }

  func localBranch(tracking remoteBranch: FakeRemoteBranch) -> FakeLocalBranch?
  { nil }

  var localBranches: AnySequence<any Xit.LocalBranch>
  {
    let array: [LocalBranch] = [localBranch1, localBranch2]
    return AnySequence(array)
  }
  
  var remoteBranches: AnySequence<any Xit.RemoteBranch>
  {
    let array: [any Xit.RemoteBranch] = [remoteBranch1, remoteBranch2]
    return AnySequence(array)
  }
}

extension FakeRepo: EmptyCommitStorage
{
  typealias Commit = StringCommit

  func oid(forSHA sha: String) -> StringOID? { .init(rawValue: sha) }

  func commit(forSHA sha: String) -> StringCommit?
  { commits[StringOID(rawValue: sha)] }
  func commit(forOID oid: StringOID) -> StringCommit? { commits[oid] }
  func commit(message: String, amend: Bool) throws {}

  func walker() -> RevWalk? { return nil }
}

extension FakeRepo: EmptyStashing
{
  var stashes: AnyCollection<any Stash> { return AnyCollection([]) }
  func stash(index: UInt, message: String?) -> any Stash { return FakeStash() }
}

extension FakeRepo: CommitReferencing
{
  typealias RemoteBranch = FakeRemoteBranch
  typealias Reference = FakeReference
  typealias Tag = FakeTag
  typealias Tree = StringTree

  var headRef: String? { nil }

  func tags() throws -> [FakeTag] { [] }
  func graphBetween(localBranch: FakeLocalBranch,
                    upstreamBranch: FakeRemoteBranch)
    -> (ahead: Int, behind: Int)?
  { nil }

  func remoteBranch(named name: String, remote: String) -> FakeRemoteBranch?
  { nil }

  func reference(named name: String) -> FakeReference? { nil }

  func createCommit(with tree: Xit.StringTree, message: String, parents: [Xit.StringCommit], updatingReference refName: String) throws -> StringOID
  { "" }

  func oid(forRef: String) -> StringOID? { nil }
  func sha(forRef: String) -> String? { nil }
  func refs(at oid: StringOID) -> [String] { [] }
  func allRefs() -> [String] { [] }
  func rebuildRefsIndex() {}
}

extension FakeRepo: FileContents
{
  var repoURL: URL
  { preconditionFailure("FakeRepo has no URL") }

  func isTextFile(_ path: String, context: Xit.FileContext) -> Bool { true }
  func fileBlob(ref: String, path: String) -> (Xit.Blob)? { nil }
  func stagedBlob(file: String) -> (Xit.Blob)? { nil }
  func contentsOfFile(path: String, at commit: any Xit.Commit) -> Data? { nil }
  func contentsOfStagedFile(path: String) -> Data? { nil }

  func fileURL(_ file: String) -> URL
  { preconditionFailure("FakeRepo has no URL") }
}

extension FakeRepo: FileDiffing
{
  func diffMaker(forFile file: String,
                 commitOID: any OID,
                 parentOID: (any OID)?) -> PatchMaker.PatchResult? { nil }
  func diff(for path: String,
            commitSHA sha: String,
            parentOID: (any OID)?) -> (any DiffDelta)? { nil }
  func stagedDiff(file: String) -> PatchMaker.PatchResult? { nil }
  func unstagedDiff(file: String) -> PatchMaker.PatchResult? { nil }
  func amendingStagedDiff(file: String) -> PatchMaker.PatchResult? { nil }

  func blame(for path: String,
             from startOID: (any OID)?,
             to endOID: (any OID)?) -> (any Blame)? { nil }
  func blame(for path: String,
             data fromData: Data?,
             to endOID: (any OID)?) -> (any Blame)? { nil }
}

extension FakeRepo: FileStaging
{
  var index: (any StagingIndex)? { nil }

  func stage(file: String) throws {}
  func unstage(file: String) throws {}
  func amendStage(file: String) throws {}
  func amendUnstage(file: String) throws {}
  func revert(file: String) throws {}
  func stageAllFiles() throws {}
  func unstageAllFiles() throws {}
  func patchIndexFile(path: String, hunk: any DiffHunk, stage: Bool) throws {}
}

extension FakeRepo: FileStatusDetection
{
  func changes(for oid: any OID, parent parentOID: (any OID)?) -> [FileChange]
  { [] }

  func stagedChanges() -> [FileChange] { [] }
  func amendingStagedChanges() -> [FileChange] { [] }
  func unstagedChanges(showIgnored: Bool,
                       recurseUntracked: Bool,
                       useCache: Bool) -> [FileChange] { [] }
  func amendingStagedStatus(for path: String) throws -> DeltaStatus
  { .unmodified }
  func amendingUnstagedStatus(for path: String) throws -> DeltaStatus
  { .unmodified }
  func stagedStatus(for path: String) throws -> DeltaStatus
  { .unmodified }
  func unstagedStatus(for path: String) throws -> DeltaStatus
  { .unmodified }
  func status(file: String) throws -> (DeltaStatus, DeltaStatus)
  { (.unmodified, .unmodified) }
  func isIgnored(path: String) -> Bool { false }
}

extension FakeRepo: Stashing
{
  func popStash(index: UInt) throws {}
  func applyStash(index: UInt) throws {}
  func dropStash(index: UInt) throws {}
  func commitForStash(at index: UInt) -> (any Xit.Commit)? { return nil }
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
  
  func remote(named name: String) -> (any Remote)?
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
