// periphery:ignore:all
import Foundation
import Combine
import FakedMacro

/// A combination of all repository protocols
public typealias FullRepository =
    BasicRepository & Branching & CommitStorage & CommitReferencing & FileDiffing &
    FileContents & FileStaging & FileStatusDetection & Merging &
    RemoteManagement & RepoConfiguring & Stashing & SubmoduleManagement &
    Tagging & WritingManagement & Workspace

@Faked
public protocol BasicRepository
{
  var controller: (any RepositoryController)? { get }
}

public typealias ProgressValue = (current: Float, total: Float)

public protocol RepositoryPublishing
{
  // These all just notify that a thing in the repository has changed.
  var configPublisher: AnyPublisher<Void, Never> { get }
  var headPublisher: AnyPublisher<Void, Never> { get }
  var indexPublisher: AnyPublisher<Void, Never> { get }
  var refLogPublisher: AnyPublisher<Void, Never> { get }
  var refsPublisher: AnyPublisher<Void, Never> { get }
  var stashPublisher: AnyPublisher<Void, Never> { get }
  
  var progressPublisher: AnyPublisher<ProgressValue, Never> { get }
  
  func post(progress: Float, total: Float)

  /// Published value is the paths that changed this time.
  var workspacePublisher: AnyPublisher<[String], Never> { get }

  // Methods for manually triggering change messages without waiting for
  // changes to be detected automatically.
  func indexChanged()
  func refsChanged()
}

@Faked
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

@Faked
public protocol Cloning
{
  func clone(from source: URL, to destination: URL,
             branch: String,
             recurseSubmodules: Bool,
             publisher: RemoteProgressPublisher) throws -> (any FullRepository)?
}

@Faked
public protocol CommitStorage: AnyObject
{
  associatedtype Commit: Xit.Commit
  associatedtype RevWalk: Xit.RevWalk

  func commit(forSHA sha: SHA) -> Commit?
  func commit(forOID oid: GitOID) -> Commit?

  func commit(message: String, amend: Bool) throws
  
  func walker() -> RevWalk?
}


@Faked(types: ["Tree": "FakeTree"])
public protocol CommitReferencing: AnyObject
{
  associatedtype Commit: Xit.Commit
  associatedtype Tag: Xit.Tag
  associatedtype Tree: Xit.Tree
  associatedtype LocalBranch: Xit.LocalBranch
  associatedtype RemoteBranch: Xit.RemoteBranch

  var headRefName: (any ReferenceName)? { get }

  func oid(forRef: any ReferenceName) -> GitOID?
  func sha(forRef: any ReferenceName) -> SHA?
  func tags() throws -> [Tag]
  func graphBetween(localBranch: LocalBranch,
                    upstreamBranch: RemoteBranch) -> (ahead: Int, behind: Int)?

  func reference(named name: String) -> (any Reference)?
  func refs(at oid: GitOID) -> [String]
  func allRefs() -> [GeneralRefName]

  func rebuildRefsIndex()
  
  /// Creates a commit with the given content.
  /// - returns: The OID of the new commit.
  func createCommit(with tree: Tree,
                    message: String,
                    parents: [Commit],
                    updatingReference refName: String) throws -> GitOID
}

extension CommitReferencing
{
  var headReference: (any Reference)? { reference(named: "HEAD") }
  var headSHA: SHA? { headRefName.flatMap { self.sha(forRef: $0) } }
  var headOID: GitOID? { headRefName.flatMap { self.oid(forRef: $0) } }
}

extension CommitReferencing where Self: CommitStorage
{
  var headCommit: Commit? { headOID.flatMap { commit(forOID: $0) } }
}

@Faked
public protocol FileStatusDetection: AnyObject
{
  func changes(for oid: GitOID, parent parentOID: GitOID?) -> [FileChange]

  func stagedChanges() -> [FileChange]
  func amendingStagedChanges() -> [FileChange]
  func unstagedChanges(showIgnored: Bool,
                       recurseUntracked: Bool,
                       useCache: Bool) -> [FileChange]
  func amendingStagedStatus(for path: String) throws -> DeltaStatus
  func amendingUnstagedStatus(for path: String) throws -> DeltaStatus
  func stagedStatus(for path: String) throws -> DeltaStatus
  func unstagedStatus(for path: String) throws -> DeltaStatus
  @FakeDefault((DeltaStatus.unmodified, DeltaStatus.unmodified))
  func status(file: String) throws -> (DeltaStatus, DeltaStatus)
  func isIgnored(path: String) -> Bool
}

extension DeltaStatus: Fakable
{
  public static func fakeDefault() -> Self { .unmodified }
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

@Faked
public protocol FileDiffing: AnyObject
{
  associatedtype Blame: Xit.Blame

  func diffMaker(forFile file: String,
                 commitOID: GitOID,
                 parentOID: GitOID?) -> PatchMaker.PatchResult?
  func stagedDiff(file: String) -> PatchMaker.PatchResult?
  func unstagedDiff(file: String) -> PatchMaker.PatchResult?
  func amendingStagedDiff(file: String) -> PatchMaker.PatchResult?

  func blame(for path: String,
             from startOID: GitOID?,
             to endOID: GitOID?) -> Blame?
  func blame(for path: String,
             data fromData: Data?,
             to endOID: GitOID?) -> Blame?
}

@Faked
public protocol FileContents: AnyObject
{
  associatedtype Blob: Xit.Blob

  var repoURL: URL { get }
  
  func isTextFile(_ path: String, context: FileContext) -> Bool
  func fileBlob(ref: any ReferenceName, path: String) -> Blob?
  func stagedBlob(file: String) -> Blob?
  func contentsOfFile(path: String, at commit: any Commit) -> Data?
  func contentsOfStagedFile(path: String) -> Data?
  func fileURL(_ file: String) -> URL
}

extension URL: @retroactive Fakable
{
  public static func fakeDefault() -> Self { .init(filePath: "/") }
}

@Faked
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

@Faked
public protocol Stashing: AnyObject
{
  @FakeDefault(exp: ".init([any Stash]())")
  var stashes: AnyCollection<any Stash> { get }
  
  @FakeDefault(exp: "NullStash()")
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

@Faked
public protocol RemoteManagement: AnyObject
{
  associatedtype Remote: Xit.Remote

  func remoteNames() -> [String]
  func remote(named name: String) -> Remote?
  func addRemote(named name: String, url: URL) throws
  func deleteRemote(named name: String) throws

  /// Pushes an update for the given branch.
  /// - parameter branches: Local branches to push; must have a tracking branch set
  /// - parameter remote: Target remote to push to
  /// - parameter callbacks: Password and progress callbacks
  func push(branches: [LocalBranchRefName],
            remote: Remote,
            callbacks: RemoteCallbacks) throws

  /// Dowloads updated refs and commits from the remote.
  func fetch(remote: Remote, options: FetchOptions) throws

  /// Initiates pulling (fetching and merging) the given branch.
  /// - parameter branch: Either the local branch or the remote tracking branch.
  /// - parameter remote: The remote to pull from.
  /// - parameter options: Options for the fetch operation.
  func pull(branch: any Branch,
            remote: Remote,
            options: FetchOptions) throws
}

extension RemoteManagement
{
  func remotes() -> [Remote]
  {
    return remoteNames().compactMap { remote(named: $0) }
  }
}

@Faked
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

@Faked
public protocol SubmoduleManagement: AnyObject
{
  func submodules() -> [any Submodule]
  func addSubmodule(path: String, url: String) throws
}

@Faked
public protocol Branching: AnyObject
{
  associatedtype LocalBranch: Xit.LocalBranch
  associatedtype RemoteBranch: Xit.RemoteBranch

  /// Returns the current checked out branch, or nil if in a detached head state
  var currentBranch: LocalBranchRefName? { get }
  var localBranches: AnySequence<LocalBranch> { get }
  var remoteBranches: AnySequence<RemoteBranch> { get }
  
  /// Creates a branch at the given target ref
  func createBranch(named name: String,
                    target: String) throws -> LocalBranch?
  func rename(branch: String, to: String) throws
  func localBranch(named refName: LocalBranchRefName) -> LocalBranch?
  func remoteBranch(named name: String) -> RemoteBranch?
  func remoteBranch(named name: String, remote: String) -> RemoteBranch?
  func localBranch(tracking remoteBranch: RemoteBranch) -> LocalBranch?
  func localTrackingBranch(forBranch branch: RemoteBranchRefName) -> LocalBranch?

  /// Resets the current branch to the specified commit
  func reset(toCommit target: any Commit, mode: ResetMode) throws
}

extension Branching
{
  /// Returns the branch itself if it is a local branch, or a branch tracking
  /// it if it is a remote branch.
  func localBranch(for branch: any Branch) -> LocalBranch?
  {
    if let local = branch as? LocalBranch {
      return local
    }
    else if let remote = branch as? RemoteBranch {
      return localBranch(tracking: remote)
    }
    else {
      return nil
    }
  }
}

public protocol Merging: AnyObject
{
  func merge(branch: any Branch) throws
  // In the future, expose more merge analysis and options
}

public enum ResetMode: Sendable
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

enum TrackingBranchStatus: Sendable
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
    if let localBranchRef = LocalBranchRefName(branch),
       let localBranch = localBranch(named: localBranchRef),
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

@Faked
public protocol Tagging: AnyObject
{
  func createTag(name: String, targetOID: GitOID, message: String?) throws
  func createLightweightTag(name: String, targetOID: GitOID) throws
  func deleteTag(name: String) throws
}

@Faked
public protocol Workspace: AnyObject
{
  func checkOut(branch: String) throws
  func checkOut(refName: String) throws
  func checkOut(sha: SHA) throws
}
