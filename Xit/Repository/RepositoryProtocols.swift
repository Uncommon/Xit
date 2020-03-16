import Foundation

public typealias Repository =
    BasicRepository & Branching & CommitStorage & CommitReferencing & FileDiffing &
    FileContents & FileStaging & FileStatusDetection & RemoteCommunication &
    RemoteManagement & RepoConfiguring & Stashing & SubmoduleManagement & Tagging &
    WritingManagement & Workspace

public protocol BasicRepository
{
  var controller: RepositoryController? { get set }
}

public protocol WritingManagement
{
  var isWriting: Bool { get }

  func performWriting(_ block: (() throws -> Void)) throws
}

public protocol RepoConfiguring
{
  var config: Config { get }
}

public protocol CommitStorage: AnyObject
{
  func oid(forSHA sha: String) -> OID?
  func commit(forSHA sha: String) -> Commit?
  func commit(forOID oid: OID) -> Commit?
  
  func commit(message: String, amend: Bool) throws
  
  func walker() -> RevWalk?
}

public protocol CommitReferencing: AnyObject
{
  var headRef: String? { get }
  var currentBranch: String? { get }
  
  func oid(forRef: String) -> OID?
  func sha(forRef: String) -> String?
  func tags() throws -> [Tag]
  func graphBetween(localBranch: LocalBranch,
                    upstreamBranch: RemoteBranch) -> (ahead: Int, behind: Int)?
  
  func localBranch(named name: String) -> LocalBranch?
  func remoteBranch(named name: String, remote: String) -> RemoteBranch?
  
  func reference(named name: String) -> Reference?
  func refs(at sha: String) -> [String]
  func allRefs() -> [String]
  
  func rebuildRefsIndex()
  
  /// Creates a commit with the given content.
  /// - returns: The OID of the new commit.
  func createCommit(with tree: Tree, message: String, parents: [Commit],
                    updatingReference refName: String) throws -> OID
}

extension CommitReferencing
{
  var headReference: Reference? { return reference(named: "HEAD") }
  var headSHA: String? { return headRef.flatMap { self.sha(forRef: $0) } }
}

public protocol FileStatusDetection: AnyObject
{
  func changes(for sha: String, parent parentOID: OID?) -> [FileChange]

  func stagedChanges() -> [FileChange]
  func amendingStagedChanges() -> [FileChange]
  func unstagedChanges(showIgnored: Bool) -> [FileChange]
  func amendingStagedStatus(for path: String) throws -> DeltaStatus
  func amendingUnstagedStatus(for path: String) throws -> DeltaStatus
  func stagedStatus(for path: String) throws -> DeltaStatus
  func unstagedStatus(for path: String) throws -> DeltaStatus
  func isIgnored(path: String) -> Bool
}

extension FileStatusDetection
{
  // Because protocols can't have default parameter values
  func unstagedChanges() -> [FileChange]
  {
    return unstagedChanges(showIgnored: false)
  }
}

public protocol FileDiffing: AnyObject
{
  func diffMaker(forFile file: String,
                 commitOID: OID,
                 parentOID: OID?) -> PatchMaker.PatchResult?
  func diff(for path: String,
            commitSHA sha: String,
            parentOID: OID?) -> DiffDelta?
  func stagedDiff(file: String) -> PatchMaker.PatchResult?
  func unstagedDiff(file: String) -> PatchMaker.PatchResult?
  func amendingStagedDiff(file: String) -> PatchMaker.PatchResult?
  
  func blame(for path: String, from startOID: OID?, to endOID: OID?) -> Blame?
  func blame(for path: String, data fromData: Data?, to endOID: OID?) -> Blame?
}

public protocol FileContents: AnyObject
{
  var repoURL: URL { get }
  
  func isTextFile(_ path: String, context: FileContext) -> Bool
  func fileBlob(ref: String, path: String) -> Blob?
  func stagedBlob(file: String) -> Blob?
  func contentsOfFile(path: String, at commit: Commit) -> Data?
  func contentsOfStagedFile(path: String) -> Data?
  func fileURL(_ file: String) -> URL
}

public protocol FileStaging: AnyObject
{
  var index: StagingIndex? { get }
  
  func stage(file: String) throws
  func unstage(file: String) throws
  func amendStage(file: String) throws
  func amendUnstage(file: String) throws
  func revert(file: String) throws
  func stageAllFiles() throws
  func unstageAllFiles() throws
}

public protocol Stashing: AnyObject
{
  var stashes: AnyCollection<Stash> { get }
  
  func stash(index: UInt, message: String?) -> Stash
  func popStash(index: UInt) throws
  func applyStash(index: UInt) throws
  func dropStash(index: UInt) throws
  func commitForStash(at index: UInt) -> Commit?
  
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
  func remote(named name: String) -> Remote?
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
  var progress: Float { return Float(receivedObjects) / Float(totalObjects) }
}

public struct RemoteCallbacks
{
  /// Callback for getting the user and password
  let passwordBlock: (() -> (String, String)?)?
  /// Fetch progress. Return false to stop the operation
  let downloadProgress: ((TransferProgress) -> Bool)?
  /// Push progress. Return false to stop the operation
  let uploadProgress: ((PushTransferProgress) -> Bool)?
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
  /// - parameter branch: Local branch to push; must have a tracking branch set
  /// - parameter remote: Target remote to push to
  /// - parameter callbacks: Password and progress callbacks
  func push(branch: LocalBranch,
            remote: Remote,
            callbacks: RemoteCallbacks) throws
  
  /// Dowloads updated refs and commits from the remote.
  func fetch(remote: Remote, options: FetchOptions) throws
  
  /// Initiates pulling (fetching and merging) the given branch.
  /// - parameter branch: Either the local branch or the remote tracking branch.
  /// - parameter remote: The remote to pull from.
  /// - parameter options: Options for the fetch operation.
  func pull(branch: Branch,
            remote: Remote,
            options: FetchOptions) throws
}

public protocol SubmoduleManagement: AnyObject
{
  func submodules() -> [Submodule]
  func addSubmodule(path: String, url: String) throws
}

public protocol Branching: AnyObject
{
  /// Returns the current checked out branch, or nil if in a detached head state
  var currentBranch: String? { get }
  var localBranches: AnySequence<LocalBranch> { get }
  var remoteBranches: AnySequence<RemoteBranch> { get }
  
  /// Creates a branch at the given target ref
  func createBranch(named name: String, target: String) throws -> LocalBranch?
  func rename(branch: String, to: String) throws
  func localBranch(named name: String) -> LocalBranch?
  func remoteBranch(named name: String) -> RemoteBranch?
  func localBranch(tracking remoteBranch: RemoteBranch) -> LocalBranch?
  func localTrackingBranch(forBranchRef branch: String) -> LocalBranch?
  
  /// Resets the current branch to the specified commit
  func reset(toCommit target: Commit, mode: ResetMode) throws
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
  func createTag(name: String, targetOID: OID, message: String?) throws
  func createLightweightTag(name: String, targetOID: OID) throws
  func deleteTag(name: String) throws
}

public protocol Workspace: AnyObject
{
  func checkOut(branch: String) throws
  func checkOut(refName: String) throws
  func checkOut(sha: String) throws
}
