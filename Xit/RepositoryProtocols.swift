import Foundation

public protocol CommitStorage: class
{
  func commit(forSHA sha: String) -> Commit?
  func commit(forOID oid: OID) -> Commit?
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
  associatedtype ID: OID

  func changes(for sha: String, parent parentOID: ID) -> [FileChange]
}

public protocol FileDiffing: class
{
  func diffMaker(forFile file: String,
                 commitOID: OID,
                 parentOID: OID?) -> XTDiffMaker.DiffResult?
  func diff(for path: String,
            commitSHA sha: String,
            parentOID: OID?) -> XTDiffDelta?
  func stagedDiff(file: String) -> XTDiffMaker.DiffResult?
  func unstagedDiff(file: String) -> XTDiffMaker.DiffResult?
  
  func blame(for path: String, from startOID: OID?, to endOID: OID?) -> Blame?
  func blame(for path: String, data fromData: Data?, to endOID: OID?) -> Blame?
}

public protocol FileContents: class
{
  var repoURL: URL { get }
  
  func isTextFile(_ path: String, commit: String?) -> Bool
  func fileBlob(ref: String, path: String) -> Blob?
  func stagedBlob(file: String) -> Blob?
  func contentsOfFile(path: String, at commit: Commit) -> Data?
  func contentsOfStagedFile(path: String) -> Data?
  func fileURL(_ file: String) -> URL
}

public protocol FileStaging: class
{
  var workspaceStatus: [String: WorkspaceFileStatus] { get }
  
  func changes(for sha: String, parent parentOID: OID?) -> [FileChange]
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
  func submodules() -> [XTSubmodule]
  func addSubmodule(path: String, url: String) throws
}

public protocol Branching: class
{
  var currentBranch: String? { get }
  
  func localBranch(named name: String) -> LocalBranch
  func remoteBranch(named name: String) -> RemoteBranch
}
