// periphery:ignore:all
import Foundation
import Combine

/// A combination of all repository protocols
public typealias FullRepository =
    BasicRepository & Branching & CommitStorage & CommitReferencing & FileDiffing &
    FileContents & FileStaging & FileStatusDetection & Merging &
    RemoteCommunication & RemoteManagement & RepoConfiguring & Stashing &
    SubmoduleManagement & Tagging & WritingManagement & Workspace

public protocol BasicRepository
{
  var controller: (any RepositoryController)? { get set }
}

public protocol RepositoryPublishing
{
  // These all just notify that a thing in the repository has changed.
  var configPublisher: AnyPublisher<Void, Never> { get }
  var headPublisher: AnyPublisher<Void, Never> { get }
  var indexPublisher: AnyPublisher<Void, Never> { get }
  var refLogPublisher: AnyPublisher<Void, Never> { get }
  var refsPublisher: AnyPublisher<Void, Never> { get }
  var stashPublisher: AnyPublisher<Void, Never> { get }

  /// Published value is the paths that changed this time.
  var workspacePublisher: AnyPublisher<[String], Never> { get }

  // Methods for manually triggering change messages without waiting for
  // changes to be detected automatically.
  func indexChanged()
  func refsChanged()
}

public protocol WritingManagement
{
  /// True if the repository is currently performing a writing operation.
  var isWriting: Bool { get }

  /// Performs `block` with `isWriting` set to true. Throws an exception if
  /// `isWriting` is already true.
  func performWriting(_ block: (() throws -> Void)) throws
}

public protocol RepoConfiguring
{
  var config: any Config { get }
}

public protocol Cloning
{
  func clone(from source: URL, to destination: URL,
             branch: String,
             recurseSubmodules: Bool,
             publisher: RemoteProgressPublisher) throws -> (any FullRepository)?
}

public protocol CommitStorage<ID>: AnyObject
{
  associatedtype ID: OID
  associatedtype Commit: Xit.Commit<ID>

  func oid(forSHA sha: String) -> ID?
  func commit(forSHA sha: String) -> Commit?
  func commit(forOID oid: ID) -> Commit?
  
  func commit(message: String, amend: Bool) throws
  
  func walker() -> (any RevWalk)?
}

extension CommitStorage
{
  // Helper for dealing with a `CommitStorage` existential because the caller
  // doesn't know the OID type.
  func anyCommit(forOID oid: any OID) -> (any Xit.Commit)?
  {
    guard let oid = oid as? ID
    else {
      assertionFailure("wrong OID type")
      return nil
    }
    return commit(forOID: oid) as (any Xit.Commit)?
  }
}

/// Convenience function to unwrap a `CommitStorage` existential.
func commit<R>(from repo: R,
               forOID id: (any OID)?) -> (any Commit)? where R: CommitStorage
{
  guard let id = id as? R.ID
  else { return nil }
  return repo.commit(forOID: id)
}

public protocol CommitReferencing<ID>: AnyObject
{
  associatedtype ID: OID
  associatedtype Commit: Xit.Commit<ID>
  associatedtype LocalBranch: Xit.LocalBranch
      where LocalBranch.ObjectIdentifier == ID
  associatedtype RemoteBranch: Xit.RemoteBranch
      where LocalBranch.ObjectIdentifier == ID
  associatedtype Reference: Xit.Reference
      where Reference.ID == ID
  associatedtype Tag: Xit.Tag<ID>
  associatedtype Tree: Xit.Tree<ID>

  var headRef: String? { get }
  var currentBranch: String? { get }
  
  func oid(forRef: String) -> ID?
  func sha(forRef: String) -> String?
  func tags() throws -> [Tag]
  func graphBetween(localBranch: LocalBranch,
                    upstreamBranch: RemoteBranch) -> (ahead: Int,
                                                      behind: Int)?
  
  func localBranch(named name: String) -> LocalBranch?
  func remoteBranch(named name: String, remote: String) -> RemoteBranch?
  
  func reference(named name: String) -> Reference?
  func refs(at oid: ID) -> [String]
  func allRefs() -> [String]
  
  func rebuildRefsIndex()
  
  /// Creates a commit with the given content.
  /// - returns: The OID of the new commit.
  func createCommit(with tree: Tree,
                    message: String,
                    parents: [Commit],
                    updatingReference refName: String) throws -> ID
}

/// Convenience function to unwrap a `CommitReferencing` existential.
func refs<R>(from repo: R, at oid: any OID) -> [String]
  where R: CommitReferencing
{
  guard let oid = oid as? R.ID
  else { return [] }
  return repo.refs(at: oid)
}

extension CommitReferencing
{
  var headReference: Reference? { reference(named: "HEAD") }
  var headSHA: String? { headRef.flatMap { self.sha(forRef: $0) } }
  var headOID: ID? { headRef.flatMap { self.oid(forRef: $0) } }
}

extension CommitReferencing where Self: CommitStorage
{
  var headCommit: Commit? { headOID.flatMap { commit(forOID: $0) } }

  var anyHeadCommit: (any Xit.Commit)? { headCommit as (any Xit.Commit)? }
}

public protocol FileStatusDetection: AnyObject
{
  func changes(for oid: any OID, parent parentOID: (any OID)?) -> [FileChange]

  func stagedChanges() -> [FileChange]
  func amendingStagedChanges() -> [FileChange]
  func unstagedChanges(showIgnored: Bool,
                       recurseUntracked: Bool,
                       useCache: Bool) -> [FileChange]
  func amendingStagedStatus(for path: String) throws -> DeltaStatus
  func amendingUnstagedStatus(for path: String) throws -> DeltaStatus
  func stagedStatus(for path: String) throws -> DeltaStatus
  func unstagedStatus(for path: String) throws -> DeltaStatus
  func status(file: String) throws -> (DeltaStatus, DeltaStatus)
  func isIgnored(path: String) -> Bool
}

extension FileStatusDetection
{
  // Because protocols can't have default parameter values
  func unstagedChanges() -> [FileChange]
  {
    return unstagedChanges(showIgnored: false,
                           recurseUntracked: true,
                           useCache: true)
  }

  func unstagedChanges(showIgnored: Bool) -> [FileChange]
  {
    unstagedChanges(showIgnored: showIgnored,
                    recurseUntracked: true,
                    useCache: true)
  }
}

public protocol FileDiffing: AnyObject
{
  func diffMaker(forFile file: String,
                 commitOID: any OID,
                 parentOID: (any OID)?) -> PatchMaker.PatchResult?
  func stagedDiff(file: String) -> PatchMaker.PatchResult?
  func unstagedDiff(file: String) -> PatchMaker.PatchResult?
  func amendingStagedDiff(file: String) -> PatchMaker.PatchResult?

  func blame(for path: String,
             from startOID: (any OID)?,
             to endOID: (any OID)?) -> (any Blame)?
  func blame(for path: String,
             data fromData: Data?,
             to endOID: (any OID)?) -> (any Blame)?
}

public protocol FileContents: AnyObject
{
  var repoURL: URL { get }
  
  func isTextFile(_ path: String, context: FileContext) -> Bool
  func fileBlob(ref: String, path: String) -> (any Blob)?
  func stagedBlob(file: String) -> (any Blob)?
  func contentsOfFile(path: String, at commit: any Commit) -> Data?
  func contentsOfStagedFile(path: String) -> Data?
  func fileURL(_ file: String) -> URL
}

public protocol FileStaging: AnyObject
{
  var index: (any StagingIndex)? { get }
  
  func stage(file: String) throws
  func unstage(file: String) throws
  func amendStage(file: String) throws
  func amendUnstage(file: String) throws
  func revert(file: String) throws
  func stageAllFiles() throws
  func unstageAllFiles() throws
  func patchIndexFile(path: String, hunk: any DiffHunk, stage: Bool) throws
}

extension FileStaging
{
  public func stage(change: FileChange) throws
  {
    try stage(file: change.gitPath)
    if change.status == .renamed && !change.oldPath.isEmpty {
      try stage(file: change.oldPath)
    }
  }

  public func unstage(change: FileChange) throws
  {
    try unstage(file: change.gitPath)
    if change.status == .renamed && !change.oldPath.isEmpty {
      try unstage(file: change.oldPath)
    }
  }
}

public protocol Stashing: AnyObject
{
  var stashes: AnyCollection<any Stash> { get }
  
  func stash(index: UInt, message: String?) -> any Stash
  func popStash(index: UInt) throws
  func applyStash(index: UInt) throws
  func dropStash(index: UInt) throws
  func commitForStash(at index: UInt) -> (any Commit)?
  
  /// Make a new stash entry
  /// - parameter name: Name of the stash entry
  /// - parameter keepIndex: Do not stash staged changes
  /// - parameter includeUntracked: Stash untracked workspace files
  /// - parameter includeIgnored: Stash ignored workspace files
  func saveStash(name: String?,
                 keepIndex: Bool,
                 includeUntracked: Bool,
                 includeIgnored: Bool) throws
}

public protocol RemoteManagement: AnyObject
{
  func remoteNames() -> [String]
  func remote(named name: String) -> (any Remote)?
  func addRemote(named name: String, url: URL) throws
  func deleteRemote(named name: String) throws
}

extension RemoteManagement
{
  func remotes() -> [any Remote]
  {
    return remoteNames().compactMap { remote(named: $0) }
  }
}

public protocol TransferProgress: Sendable
{
  var totalObjects: UInt32 { get }
  var indexedObjects: UInt32 { get }
  var receivedObjects: UInt32 { get }
  var localObjects: UInt32 { get }
  var totalDeltas: UInt32 { get }
  var indexedDeltas: UInt32 { get }
  var receivedBytes: Int { get }
}

extension TransferProgress
{
  var progress: Float { Float(receivedObjects) / Float(totalObjects) }
}

struct MockTransferProgress: TransferProgress
{
  var totalObjects: UInt32
  var indexedObjects: UInt32
  var receivedObjects: UInt32
  var localObjects: UInt32
  var totalDeltas: UInt32
  var indexedDeltas: UInt32
  var receivedBytes: Int
}

public struct RemoteCallbacks
{
  typealias PasswordBlock = () -> (String, String)?
  typealias DownloadProgressBlock = (any TransferProgress) -> Bool
  typealias UploadProgressBlock = (PushTransferProgress) -> Bool
  typealias SidebandMessageBlock = (String) -> Bool

  /// Callback for getting the user and password when they could not be
  /// discovered automatically
  var passwordBlock: PasswordBlock? = nil
  /// Fetch progress. Return false to stop the operation
  var downloadProgress: DownloadProgressBlock? = nil
  /// Push progress. Return false to stop the operation
  var uploadProgress: UploadProgressBlock? = nil
  /// Message from the server
  var sidebandMessage: SidebandMessageBlock? = nil
}

public struct FetchOptions
{
  /// True to also download tags
  let downloadTags: Bool
  /// True to delete obsolete branch refs
  let pruneBranches: Bool
  
  let callbacks: RemoteCallbacks
}

public struct PushTransferProgress: Sendable
{
  let current, total: UInt32
  let bytes: size_t
}

public protocol RemoteCommunication: AnyObject
{
  /// Pushes an update for the given branch.
  /// - parameter branches: Local branches to push; must have a tracking branch set
  /// - parameter remote: Target remote to push to
  /// - parameter callbacks: Password and progress callbacks
  func push(branches: [any LocalBranch],
            remote: any Remote,
            callbacks: RemoteCallbacks) throws
  
  /// Dowloads updated refs and commits from the remote.
  func fetch(remote: any Remote, options: FetchOptions) throws
  
  /// Initiates pulling (fetching and merging) the given branch.
  /// - parameter branch: Either the local branch or the remote tracking branch.
  /// - parameter remote: The remote to pull from.
  /// - parameter options: Options for the fetch operation.
  func pull(branch: any Branch,
            remote: any Remote,
            options: FetchOptions) throws
}

public protocol SubmoduleManagement: AnyObject
{
  func submodules() -> [any Submodule]
  func addSubmodule(path: String, url: String) throws
}

public protocol Branching: AnyObject
{
  associatedtype Commit: Xit.Commit
  associatedtype LocalBranch: Xit.LocalBranch
  typealias RemoteBranch = LocalBranch.RemoteBranch

  /// Returns the current checked out branch, or nil if in a detached head state
  var currentBranch: String? { get }
  // TODO: Convert to `any Sequence<LocalBranch>` once the deployment target
  // is changed to macOS 13.
  var localBranches: AnySequence<any Xit.LocalBranch> { get }
  var remoteBranches: AnySequence<any Xit.RemoteBranch> { get }

  /// Creates a branch at the given target ref
  func createBranch(named name: String,
                    target: String) throws -> LocalBranch?
  func rename(branch: String, to: String) throws
  func localBranch(named name: String) -> LocalBranch?
  func remoteBranch(named name: String) -> RemoteBranch?
  func localBranch(tracking remoteBranch: RemoteBranch) -> LocalBranch?
  func localTrackingBranch(forBranchRef branch: String) -> LocalBranch?
  
  /// Resets the current branch to the specified commit
  func reset(toCommit target: Commit, mode: ResetMode) throws
}

extension Branching
{
  func anyLocalBranch(tracking remoteBranch: any Xit.RemoteBranch)
    -> (any Xit.LocalBranch)?
  {
    guard let remoteBranch = remoteBranch as? RemoteBranch
    else { return nil }
    return localBranch(tracking: remoteBranch) as (any Xit.LocalBranch)?
  }
}

public protocol Merging: AnyObject
{
  func merge(branch: any Branch) throws
  // In the future, expose more merge analysis and options
}

public enum ResetMode
{
  /// Does not touch the index file or the working tree at all
  case soft
  /// Resets the index but not the working tree
  case mixed
  /// Resets the index and working tree
  case hard
  
  /* These modes exist for command line git reset,
     but are not yet implemented for git_reset()
  /// Resets unchanged files, keeps changes; aborts on conflict
  case merge
  /// Resets index entries and updates files in the working tree that are
  /// different between `<commit>` and `HEAD`. If a file that is different
  /// between `<commit>` and `HEAD` has local changes, reset is aborted.
  case keep
  */
}

enum TrackingBranchStatus
{
  /// No tracking branch set
  case none
  /// References a non-existent branch
  case missing(String)
  /// References a real branch
  case set(String)
}

extension Branching
{
  func trackingBranchStatus(for branch: String) -> TrackingBranchStatus
  {
    if let localBranch = localBranch(named: branch),
       let trackingBranchName = localBranch.trackingBranchName {
      return remoteBranch(named: trackingBranchName) == nil
          ? .missing(trackingBranchName)
          : .set(trackingBranchName)
    }
    else {
      return .none
    }
  }
}

public protocol Tagging: AnyObject
{
  func createTag(name: String, targetOID: any OID, message: String?) throws
  func createLightweightTag(name: String, targetOID: any OID) throws
  func deleteTag(name: String) throws
}

public protocol Workspace: AnyObject
{
  func checkOut(branch: String) throws
  func checkOut(refName: String) throws
  func checkOut(sha: String) throws
}
