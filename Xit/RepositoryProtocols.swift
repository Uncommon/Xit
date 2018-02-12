import Foundation

public typealias Repository =
    CommitStorage & CommitReferencing & FileDiffing & FileContents & FileStaging &
    Stashing & RemoteManagement & SubmoduleManagement & Branching &
    FileStatusDetection
    // BranchListing (associated types)

public protocol CommitStorage: class
{
  func oid(forSHA sha: String) -> OID?
  func commit(forSHA sha: String) -> Commit?
  func commit(forOID oid: OID) -> Commit?
  
  func walker() -> RevWalk?
}

public protocol CommitReferencing: class
{
  var headRef: String? { get }
  var currentBranch: String? { get }
  
  func remoteNames() -> [String]
  func tags() throws -> [Tag]
  func graphBetween(localBranch: LocalBranch,
                    upstreamBranch: RemoteBranch) -> (ahead: Int, behind: Int)?
  
  func localBranch(named name: String) -> LocalBranch?
  func remoteBranch(named name: String, remote: String) -> RemoteBranch?
  
  func reference(named name: String) -> Reference?
}

extension CommitReferencing
{
  var headReference: Reference?
  {
    return reference(named: "HEAD")
  }
}

public protocol BranchListing: class
{
  associatedtype LocalBranchSequence: Sequence
      where LocalBranchSequence.Iterator.Element: LocalBranch
  associatedtype RemoteBranchSequence: Sequence
      where RemoteBranchSequence.Iterator.Element: RemoteBranch

  func localBranches() -> LocalBranchSequence
  func remoteBranches() -> RemoteBranchSequence
}

public protocol FileStatusDetection: class
{
  var workspaceStatus: [String: WorkspaceFileStatus] { get }
  
  func changes(for sha: String, parent parentOID: OID?) -> [FileChange]

  func stagedChanges() -> [FileChange]
  func unstagedChanges() -> [FileChange]
}

public protocol FileDiffing: class
{
  func diffMaker(forFile file: String,
                 commitOID: OID,
                 parentOID: OID?) -> PatchMaker.PatchResult?
  func diff(for path: String,
            commitSHA sha: String,
            parentOID: OID?) -> DiffDelta?
  func stagedDiff(file: String) -> PatchMaker.PatchResult?
  func unstagedDiff(file: String) -> PatchMaker.PatchResult?
  
  func blame(for path: String, from startOID: OID?, to endOID: OID?) -> Blame?
  func blame(for path: String, data fromData: Data?, to endOID: OID?) -> Blame?
}

public protocol FileContents: class
{
  var repoURL: URL { get }
  
  func isTextFile(_ path: String, context: FileContext) -> Bool
  func fileBlob(ref: String, path: String) -> Blob?
  func stagedBlob(file: String) -> Blob?
  func contentsOfFile(path: String, at commit: Commit) -> Data?
  func contentsOfStagedFile(path: String) -> Data?
  func fileURL(_ file: String) -> URL
}

public protocol FileStaging: class
{
  func stage(file: String) throws
  func unstage(file: String) throws
  func stageAllFiles() throws
}

public protocol Stashing: class
{
  func stash(index: UInt, message: String?) -> Stash
  func popStash(index: UInt) throws
  func applyStash(index: UInt) throws
  func dropStash(index: UInt) throws
  func commitForStash(at index: UInt) -> Commit?
}

public protocol RemoteManagement: class
{
  func remote(named name: String) -> Remote?
  func addRemote(named name: String, url: URL) throws
  func deleteRemote(named name: String) throws
}

public protocol SubmoduleManagement: class
{
  func submodules() -> [Submodule]
  func addSubmodule(path: String, url: String) throws
}

public protocol Branching: class
{
  var currentBranch: String? { get }
  
  func localBranch(named name: String) -> LocalBranch?
  func remoteBranch(named name: String) -> RemoteBranch?
}
