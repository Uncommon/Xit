import Foundation
@testable import Xit

/// Empty implementations of all the repository protocols.
/// For these types, "Empty" is used for sub-protocols with default
/// implementations that do nothing. "Null" is for concrete types whose
/// instances represent null or empty values.

protocol EmptyBasicRepository: BasicRepository {}

extension EmptyBasicRepository
{
  var controller: (any RepositoryController)? { get { nil } set {} }
}

protocol EmptyBranching: Branching {}

extension EmptyBranching
{
  var currentBranch: String? { nil }
  var localBranches: AnySequence<any LocalBranch>
  { .init(Array<NullLocalBranch>()) }
  var remoteBranches: AnySequence<any RemoteBranch>
  { .init(Array<NullRemoteBranch>()) }

  /// Creates a branch at the given target ref
  func createBranch(named name: String,
                    target: String) throws -> (any LocalBranch)? { nil }
  func rename(branch: String, to: String) throws {}
  func localBranch(named name: String) -> (any LocalBranch)? { nil }
  func remoteBranch(named name: String) -> (any RemoteBranch)? { nil }
  func localBranch(tracking remoteBranch: any RemoteBranch) -> (any LocalBranch)?
  { nil }
  func localTrackingBranch(forBranchRef branch: String) -> (any LocalBranch)?
  { nil }
  func reset(toCommit target: any Commit, mode: ResetMode) throws {}
}

class NullLocalBranch: LocalBranch
{
  var trackingBranchName: String? { get { nil } set {} }
  var trackingBranch: NullRemoteBranch? { nil }
  var name: String { "refs/heads/branch" }
  var shortName: String { "branch" }
  var oid: StringOID? { nil }
  var targetCommit: StringCommit? { nil }
}

class NullRemoteBranch: RemoteBranch
{
  var name: String { "refs/remotes/origin/branch" }
  var shortName: String { "origin/branch" }
  var oid: StringOID? { nil }
  var targetCommit: StringCommit? { nil }
  var remoteName: String? { nil }
}

protocol EmptyCommitStorage: CommitStorage {}

extension EmptyCommitStorage
{
  func oid(forSHA sha: String) -> (any OID)?  { nil }
  func commit(forSHA sha: String) -> (any Commit)? { nil }
  func commit(forOID oid: any OID) -> (any Commit)? { nil }

  func commit(message: String, amend: Bool) throws {}

  func walker() -> (any RevWalk)? { nil }
}

protocol EmptyCommitReferencing: CommitReferencing {}

extension EmptyCommitReferencing
{
  var headRef: String? { nil }
  var currentBranch: String? { nil }

  func oid(forRef: String) -> (any OID)? { nil }
  func sha(forRef: String) -> String? { nil }
  func tags() throws -> [any Tag] { [] }
  func graphBetween(localBranch: any LocalBranch,
                    upstreamBranch: any RemoteBranch) -> (ahead: Int,
                                                          behind: Int)?
  { nil }

  func localBranch(named name: String) -> (any LocalBranch)? { nil }
  func remoteBranch(named name: String, remote: String) -> (any RemoteBranch)?
  { nil }

  func reference(named name: String) -> (any Reference)? { nil }
  func refs(at oid: any OID) -> [String] { [] }
  func allRefs() -> [String] { [] }

  func rebuildRefsIndex() {}

  func createCommit(with tree: any Tree,
                    message: String,
                    parents: [any Commit],
                    updatingReference refName: String) throws -> any OID
  { §"" }
}

class NullCommit: Commit
{
  typealias ObjectIdentifier = StringOID
  typealias Tree = NullTree

  var id:  StringOID { §"" }
  var parentOIDs: [StringOID] { [] }
  var message: String? { nil }
  var authorSig: Signature? { nil }
  var committerSig: Signature? { nil }
  var tree: NullTree? { nil }
  var isSigned: Bool { false }

  func getTrailers() -> [(String, [String])] { [] }
}

class NullTree: Tree
{
  typealias ObjectIdentifier = StringOID

  struct Entry: TreeEntry
  {
    typealias ObjectIdentifier = StringOID

    var id: StringOID { §"" }
    var type: GitObjectType { .invalid }
    var name: String { "" }
    var object: (any OIDObject)? { nil }
  }

  var id: StringOID { §"" }
  var count: Int { 0 }

  func entry(named: String) -> Entry? { nil }
  func entry(path: String) -> Entry? { nil }
  func entry(at index: Int) -> Entry? { nil }
}

protocol EmptyFileStatusDetection: FileStatusDetection {}

extension EmptyFileStatusDetection
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

protocol EmptyFileDiffing: FileDiffing {}

extension EmptyFileDiffing
{
  func diffMaker(forFile file: String,
                 commitOID: any OID,
                 parentOID: (any OID)?) -> PatchMaker.PatchResult? { nil }
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

protocol EmptyFileContents: FileContents {}

extension EmptyFileContents
{
  var repoURL: URL { .init(fileURLWithPath: "/") }

  func isTextFile(_ path: String, context: FileContext) -> Bool { false }
  func fileBlob(ref: String, path: String) -> (any Blob)? { nil }
  func stagedBlob(file: String) -> (any Blob)? { nil }
  func contentsOfFile(path: String, at commit: any Commit) -> Data? { nil }
  func contentsOfStagedFile(path: String) -> Data? { nil }
  func fileURL(_ file: String) -> URL { .init(fileURLWithPath: "/") }
}

protocol EmptyFileStaging: FileStaging {}

extension EmptyFileStaging
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

protocol EmptyStashing: Stashing {}

extension EmptyStashing
{
  var stashes: AnyCollection<any Stash> { .init(Array<GitStash>()) }

  func stash(index: UInt, message: String?) -> any Stash { NullStash() }
  func popStash(index: UInt) throws {}
  func applyStash(index: UInt) throws {}
  func dropStash(index: UInt) throws {}
  func commitForStash(at index: UInt) -> (any Commit)? { nil }

  func saveStash(name: String?,
                 keepIndex: Bool,
                 includeUntracked: Bool,
                 includeIgnored: Bool) throws {}
}

protocol EmptyStash: Stash {}

extension EmptyStash
{
  var message: String? { nil }
  var mainCommit: (any Commit)? { nil }
  var indexCommit: (any Commit)? { nil }
  var untrackedCommit: (any Commit)? { nil }

  func indexChanges() -> [FileChange] { [] }
  func workspaceChanges() -> [FileChange] { [] }
  func stagedDiffForFile(_ path: String) -> PatchMaker.PatchResult? { nil }
  func unstagedDiffForFile(_ path: String) -> PatchMaker.PatchResult? { nil }
}

class NullStash: EmptyStash {}

protocol EmptyRemoteManagement: RemoteManagement {}

extension EmptyRemoteManagement
{
  func remoteNames() -> [String] { [] }
  func remote(named name: String) -> (any Remote)? { nil }
  func addRemote(named name: String, url: URL) throws {}
  func deleteRemote(named name: String) throws {}
}

public protocol EmptyRemoteCommunication: RemoteCommunication {}

extension EmptyRemoteCommunication
{
  func push(branches: [any LocalBranch],
            remote: any Remote,
            callbacks: RemoteCallbacks) throws {}
  func fetch(remote: any Remote, options: FetchOptions) throws {}
  func pull(branch: any Branch,
            remote: any Remote,
            options: FetchOptions) throws {}
}

protocol EmptyTagging: Tagging {}

extension EmptyTagging
{
  func createTag(name: String, targetOID: any OID, message: String?) throws {}
  func createLightweightTag(name: String, targetOID: any OID) throws {}
  func deleteTag(name: String) throws {}
}

protocol EmptyWorkspace: Workspace {}

extension EmptyWorkspace
{
  func checkOut(branch: String) throws {}
  func checkOut(refName: String) throws {}
  func checkOut(sha: String) throws {}
}
