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

public protocol CommitStorage: AnyObject
{
  func oid(forSHA sha: String) -> (any OID)?
  func commit(forSHA sha: String) -> (any Commit)?
  func commit(forOID oid: any OID) -> (any Commit)?
  
  func commit(message: String, amend: Bool) throws
  
  func walker() -> (any RevWalk)?
}

public protocol CommitReferencing: AnyObject
{
  var headRef: String? { get }
  var currentBranch: String? { get }
  
  func oid(forRef: String) -> (any OID)?
  func sha(forRef: String) -> String?
  func tags() throws -> [any Tag]
  func graphBetween(localBranch: any LocalBranch,
                    upstreamBranch: any RemoteBranch) -> (ahead: Int,
                                                          behind: Int)?
  
  func localBranch(named name: String) -> (any LocalBranch)?
  func remoteBranch(named name: String, remote: String) -> (any RemoteBranch)?
  
  func reference(named name: String) -> (any Reference)?
  func refs(at sha: String) -> [String]
  func allRefs() -> [String]
  
  func rebuildRefsIndex()
  
  /// Creates a commit with the given content.
  /// - returns: The OID of the new commit.
  func createCommit(with tree: any Tree,
                    message: String,
                    parents: [any Commit],
                    updatingReference refName: String) throws -> any OID
}

extension CommitReferencing
{
  var headReference: (any Reference)? { reference(named: "HEAD") }
  var headSHA: String? { headRef.flatMap { self.sha(forRef: $0) } }
}

public protocol FileStatusDetection: AnyObject
{
  func changes(for sha: String, parent parentOID: (any OID)?) -> [FileChange]

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
  func diff(for path: String,
            commitSHA sha: String,
            parentOID: (any OID)?) -> DiffDelta?
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
  func remotes() -> [Remote]
  {
    return remoteNames().compactMap { remote(named: $0) }
  }
}

public protocol TransferProgress
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
  /// Callback for getting the user and password when they could not be
  /// discovered automatically
  var passwordBlock: (() -> (String, String)?)?
  /// Fetch progress. Return false to stop the operation
  var downloadProgress: ((any TransferProgress) -> Bool)?
  /// Push progress. Return false to stop the operation
  var uploadProgress: ((PushTransferProgress) -> Bool)?
  /// Message from the server
  var sidebandMessage: ((String) -> Bool)?
  
  init(passwordBlock: (() -> (String, String)?)? = nil,
       downloadProgress: ((any TransferProgress) -> Bool)? = nil,
       uploadProgress: ((PushTransferProgress) -> Bool)? = nil,
       sidebandMessage: ((String) -> Bool)? = nil)
  {
    self.passwordBlock = passwordBlock
    self.downloadProgress = downloadProgress
    self.uploadProgress = uploadProgress
    self.sidebandMessage = sidebandMessage
  }
}

public struct FetchOptions
{
  /// True to also download tags
  let downloadTags: Bool
  /// True to delete obsolete branch refs
  let pruneBranches: Bool
  
  let callbacks: RemoteCallbacks
}

public struct PushTransferProgress
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
  /// Returns the current checked out branch, or nil if in a detached head state
  var currentBranch: String? { get }
  var localBranches: AnySequence<LocalBranch> { get }
  var remoteBranches: AnySequence<RemoteBranch> { get }
  
  /// Creates a branch at the given target ref
  func createBranch(named name: String,
                    target: String) throws -> (any LocalBranch)?
  func rename(branch: String, to: String) throws
  func localBranch(named name: String) -> (any LocalBranch)?
  func remoteBranch(named name: String) -> (any RemoteBranch)?
  func localBranch(tracking remoteBranch: any RemoteBranch) -> (any LocalBranch)?
  func localTrackingBranch(forBranchRef branch: String) -> (any LocalBranch)?
  
  /// Resets the current branch to the specified commit
  func reset(toCommit target: any Commit, mode: ResetMode) throws
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
