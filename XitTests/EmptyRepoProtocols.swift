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
  var localBranches: AnySequence<LocalBranch>
  { .init(Array<LocalBranch>()) }
  var remoteBranches: AnySequence<RemoteBranch>
  { .init(Array<RemoteBranch>()) }

  /// Creates a branch at the given target ref
  func createBranch(named name: String,
                    target: String) throws -> LocalBranch? { nil }
  func rename(branch: String, to: String) throws {}
  func localBranch(named name: LocalBranchRefName) -> LocalBranch? { nil }
  func remoteBranch(named name: String) -> RemoteBranch? { nil }
  func remoteBranch(named name: String, remote: String) -> RemoteBranch? { nil }
  func localBranch(tracking remoteBranch: RemoteBranch) -> LocalBranch? { nil }
  func localTrackingBranch(forBranch branch: RemoteBranchRefName) -> LocalBranch?
  { nil }
  func reset(toCommit target: any Commit, mode: ResetMode) throws {}
}
class NullBranching: EmptyBranching
{
  typealias LocalBranch = NullLocalBranch
  typealias RemoteBranch = NullRemoteBranch
}


class NullLocalBranch: LocalBranch
{
  var trackingBranchName: String? { get { nil } set {} }
  var trackingBranch: NullRemoteBranch? { nil }
  var name: String { "refs/heads/branch" }
  var shortName: String { "branch" }
  var oid: GitOID? { nil }
  var targetCommit: (any Commit)? { nil }
}


class NullRemoteBranch: RemoteBranch
{
  var name: String { "refs/remotes/origin/branch" }
  var shortName: String { "origin/branch" }
  var oid: GitOID? { nil }
  var targetCommit: (any Commit)? { nil }
  var remoteName: String? { nil }
}


protocol EmptyCommitStorage: CommitStorage {}
extension EmptyCommitStorage
{
  func oid(forSHA sha: String) -> GitOID?  { nil }
  func commit(forSHA sha: String) -> Commit? { nil }
  func commit(forOID oid: GitOID) -> Commit? { nil }

  func commit(message: String, amend: Bool) throws {}

  func walker() -> RevWalk? { nil }
}
class NullCommitStorage: EmptyCommitStorage
{
  typealias Commit = NullCommit
  typealias RevWalk = NullRevWalk
}


protocol EmptyRevWalk: RevWalk {}
extension EmptyRevWalk
{
  func reset() {}
  func setSorting(_ sort: RevWalkSorting) {}
  func push(oid: GitOID) {}
  func next() -> GitOID? { nil }
}
class NullRevWalk: EmptyRevWalk {}


protocol EmptyCommitReferencing: CommitReferencing {}
extension EmptyCommitReferencing
{
  var headRef: String? { nil }

  func oid(forRef: String) -> GitOID? { nil }
  func sha(forRef: String) -> String? { nil }
  func tags() throws -> [Tag] { [] }
  func graphBetween(localBranch: LocalBranch,
                    upstreamBranch: RemoteBranch) -> (ahead: Int,
                                                          behind: Int)?
  { nil }

  func reference(named name: String) -> (any Reference)? { nil }
  func refs(at oid: GitOID) -> [String] { [] }
  func allRefs() -> [String] { [] }

  func rebuildRefsIndex() {}

  func createCommit(with tree: Tree,
                    message: String,
                    parents: [Commit],
                    updatingReference refName: String) throws -> GitOID
  { .zero() }
}
class NullCommitReferencing: EmptyCommitReferencing
{
  typealias Commit = NullCommit
  typealias Tag = NullTag
  typealias Tree = NullTree
  typealias LocalBranch = NullLocalBranch
  typealias RemoteBranch = NullRemoteBranch
}


class NullCommit: Commit
{
  typealias ObjectIdentifier = GitOID
  typealias Tree = NullTree

  var id:  GitOID { §"" }
  var parentOIDs: [GitOID] { [] }
  var message: String? { nil }
  var authorSig: Signature? { nil }
  var committerSig: Signature? { nil }
  var tree: NullTree? { nil }
  var isSigned: Bool { false }

  func getTrailers() -> [(String, [String])] { [] }
}


class NullTree: Tree
{
  typealias ObjectIdentifier = GitOID

  struct Entry: TreeEntry
  {
    typealias ObjectIdentifier = GitOID

    var id: GitOID { §"" }
    var type: GitObjectType { .invalid }
    var name: String { "" }
    var object: (any OIDObject)? { nil }
  }

  var id: GitOID { .zero() }
  var count: Int { 0 }

  var entries: [Entry] { [] }

  func entry(named: String) -> Entry? { nil }
  func entry(path: String) -> Entry? { nil }
  func entry(at index: Int) -> Entry? { nil }
}


class NullTag: Tag
{
  var name: String = ""
  let signature: Signature? = nil
  let targetOID: GitOID? = nil
  let commit: NullCommit? = nil
  let message: String? = nil
  let type: TagType = .annotated
  let isSigned: Bool = false
}


struct NullBlob: Blob
{
  let dataSize: UInt = 0
  let isBinary = false

  func makeData() -> Data? { nil }
  func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
  {
    try body(.init(start: nil, count: 0))
  }
}


protocol EmptyFileStatusDetection: FileStatusDetection {}
extension EmptyFileStatusDetection
{
  func changes(for oid: GitOID, parent parentOID: GitOID?) -> [FileChange]
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
class NullFileStatusDetection: EmptyFileStatusDetection {}


protocol EmptyFileDiffing: FileDiffing {}
extension EmptyFileDiffing
{
  func diffMaker(forFile file: String,
                 commitOID: GitOID,
                 parentOID: GitOID?) -> PatchMaker.PatchResult? { nil }
  func stagedDiff(file: String) -> PatchMaker.PatchResult? { nil }
  func unstagedDiff(file: String) -> PatchMaker.PatchResult? { nil }
  func amendingStagedDiff(file: String) -> PatchMaker.PatchResult? { nil }

  func blame(for path: String,
             from startOID: GitOID?,
             to endOID: GitOID?) -> Blame? { nil }
  func blame(for path: String,
             data fromData: Data?,
             to endOID: GitOID?) -> Blame? { nil }
}
class NullFileDiffing: EmptyFileDiffing
{
  typealias Blame = NullBlame
}


protocol EmptyBlame: Blame {}
extension EmptyBlame
{
  var hunks: [BlameHunk] { [] }
}
struct NullBlame: EmptyBlame{}


protocol EmptyFileContents: FileContents {}
extension EmptyFileContents
{
  var repoURL: URL { .init(fileURLWithPath: "/") }

  func isTextFile(_ path: String, context: FileContext) -> Bool { false }
  func fileBlob(ref: String, path: String) -> Blob? { nil }
  func stagedBlob(file: String) -> Blob? { nil }
  func contentsOfFile(path: String, at commit: any Commit) -> Data? { nil }
  func contentsOfStagedFile(path: String) -> Data? { nil }
  func fileURL(_ file: String) -> URL { .init(fileURLWithPath: "/") }
}
class NullFileContents: EmptyFileContents
{
  typealias Blob = NullBlob
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
class NullFileStaging: EmptyFileStaging {}


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
class NullStashing: EmptyStashing
{
  typealias Stash = NullStash
  typealias Commit = NullCommit
}


protocol EmptyStash: Stash {}
extension EmptyStash
{
  var message: String? { nil }
  var mainCommit: NullCommit? { nil }
  var indexCommit: NullCommit? { nil }
  var untrackedCommit: NullCommit? { nil }

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
  func remote(named name: String) -> Remote? { nil }
  func addRemote(named name: String, url: URL) throws {}
  func deleteRemote(named name: String) throws {}
  func push(branches: [LocalBranch],
            remote: Remote,
            callbacks: RemoteCallbacks) throws {}
  func fetch(remote: Remote, options: FetchOptions) throws {}
  func pull(branch: any Branch,
            remote: Remote,
            options: FetchOptions) throws {}
}
class NullRemoteManagement: EmptyRemoteManagement {
  typealias LocalBranch = NullLocalBranch
  typealias Remote = NullRemote
}


protocol EmptyRemote: Remote {}
extension EmptyRemote
{
  var name: String? { nil }
  var urlString: String? { nil }
  var pushURLString: String? { nil }
  var refSpecs: AnyCollection<RefSpec> { .init([]) }

  func rename(_ name: String) throws {}
  func updateURLString(_ URLString: String?) throws {}
  func updatePushURLString(_ URLString: String?) throws {}
  func withConnection<T>(direction: Xit.RemoteConnectionDirection,
                         callbacks: Xit.RemoteCallbacks,
                         action: (any Xit.ConnectedRemote) throws -> T)
    throws -> T
  { try action(NullConnectedRemote()) }
}
class NullRemote: EmptyRemote
{

  typealias RefSpec = NullRefSpec
}


protocol EmptyConnectedRemote: ConnectedRemote {}
extension EmptyConnectedRemote
{
  var defaultBranch: String? { nil }

  func referenceAdvertisements() throws -> [RemoteHead] { [] }
}
final class NullConnectedRemote: EmptyConnectedRemote {}


protocol EmptyRefSpec: RefSpec {}
extension EmptyRefSpec
{
  var source: String { "" }
  var destination: String { "" }
  var stringValue: String { "" }
  var force: Bool { false }
  var direction: RemoteConnectionDirection { .fetch }

  func sourceMatches(refName: String) -> Bool { false }
  func destinationMatches(refName: String) -> Bool { false }
  func transformToTarget(name: String) -> String? { nil }
  func transformToSource(name: String) -> String? { nil }
}
struct NullRefSpec: EmptyRefSpec {}


protocol EmptyTagging: Tagging {}
extension EmptyTagging
{
  func createTag(name: String, targetOID: GitOID, message: String?) throws {}
  func createLightweightTag(name: String, targetOID: GitOID) throws {}
  func deleteTag(name: String) throws {}
}
class NullTagging: EmptyTagging {}


protocol EmptyWorkspace: Workspace {}
extension EmptyWorkspace
{
  func checkOut(branch: String) throws {}
  func checkOut(refName: String) throws {}
  func checkOut(sha: String) throws {}
}
class NullWorkSpace: EmptyWorkspace {}
