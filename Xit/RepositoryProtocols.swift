import Foundation

public protocol CommitStorage: class
{
  associatedtype C: CommitType
  
  func commit(forSHA sha: String) -> C?
  func commit(forOID oid: OID) -> C?
}

public protocol CommitReferencing: class
{
  var headRef: String? { get }
  var currentBranch: String? { get }
  func remoteNames() -> [String]
  func tags() throws -> [Tag]
  func graphBetween(localBranch: LocalBranch,
                    upstreamBranch: RemoteBranch) -> (ahead: Int, behind: Int)?
}

public protocol BranchListing
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
                 parentOID: OID?) -> XTDiffMaker?
  func diff(for path: String,
            commitSHA sha: String,
            parentOID: OID?) -> XTDiffDelta?
  func stagedDiff(file: String) -> XTDiffMaker?
  func unstagedDiff(file: String) -> XTDiffMaker?
  
  func blame(for path: String, from startOID: OID?, to endOID: OID?) -> Blame?
  func blame(for path: String, data fromData: Data?, to endOID: OID?) -> Blame?
}

public protocol FileContents: class
{
  func fileBlob(ref: String, path: String) -> Blob?
  func stagedBlob(file: String) -> Blob?
  func contentsOfFile(path: String, at commit: CommitType) -> Data?
  func contentsOfStagedFile(path: String) -> Data?
  func fileURL(_ file: String) -> URL
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
