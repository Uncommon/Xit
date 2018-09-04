import Foundation

public typealias Repository =
    Branching & CommitStorage & CommitReferencing & FileDiffing & FileContents &
    FileStaging & FileStatusDetection & RemoteManagement & Stashing &
    SubmoduleManagement & Tagging & Workspace
    // BranchListing (associated types)

public protocol CommitStorage: AnyObject
{
  func oid(forSHA sha: String) -> OID?
  func commit(forSHA sha: String) -> Commit?
  func commit(forOID oid: OID) -> Commit?
  
  func walker() -> RevWalk?
}

public protocol CommitReferencing: AnyObject
{
  var headRef: String? { get }
  var currentBranch: String? { get }
  
  func sha(forRef: String) -> String?
  func remoteNames() -> [String]
  func tags() throws -> [Tag]
  func graphBetween(localBranch: LocalBranch,
                    upstreamBranch: RemoteBranch) -> (ahead: Int, behind: Int)?
  
  func localBranch(named name: String) -> LocalBranch?
  func remoteBranch(named name: String, remote: String) -> RemoteBranch?
  
  func reference(named name: String) -> Reference?
  func refs(at sha: String) -> [String]
}

extension CommitReferencing
{
  var headReference: Reference?
  {
    return reference(named: "HEAD")
  }
}

extension CommitReferencing
{
  var headSHA: String? { return headRef.flatMap { self.sha(forRef: $0) } }
}

public protocol BranchListing: AnyObject
{
  associatedtype LocalBranchSequence: Sequence
      where LocalBranchSequence.Iterator.Element: LocalBranch
  associatedtype RemoteBranchSequence: Sequence
      where RemoteBranchSequence.Iterator.Element: RemoteBranch

  func localBranches() -> LocalBranchSequence
  func remoteBranches() -> RemoteBranchSequence
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
  func stash(index: UInt, message: String?) -> Stash
  func popStash(index: UInt) throws
  func applyStash(index: UInt) throws
  func dropStash(index: UInt) throws
  func commitForStash(at index: UInt) -> Commit?
  func saveStash(name: String?,
                 keepIndex: Bool,
                 includeUntracked: Bool,
                 includeIgnored: Bool) throws
}

public protocol RemoteManagement: AnyObject
{
  func remote(named name: String) -> Remote?
  func addRemote(named name: String, url: URL) throws
  func deleteRemote(named name: String) throws
}

public protocol SubmoduleManagement: AnyObject
{
  func submodules() -> [Submodule]
  func addSubmodule(path: String, url: String) throws
}

public protocol Branching: AnyObject
{
  var currentBranch: String? { get }
  
  func createBranch(named name: String, target: String) throws -> LocalBranch?
  func localBranch(named name: String) -> LocalBranch?
  func remoteBranch(named name: String) -> RemoteBranch?
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
