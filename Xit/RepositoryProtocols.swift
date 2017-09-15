import Foundation

public protocol CommitStorage: class
{
  associatedtype C: CommitType
  
  func commit(forSHA sha: String) -> C?
  func commit(forOID oid: C.ID) -> C?
}

public protocol CommitReferencing: class
{
  associatedtype LocalBranchSequence: Sequence
  associatedtype RemoteBranchSequence: Sequence
  
  var headRef: String? { get }
  var currentBranch: String? { get }
  func remoteNames() -> [String]
  func localBranches() -> LocalBranchSequence
  func remoteBranches() -> RemoteBranchSequence
  func tags() throws -> [Tag]
  func graphBetween(localBranch: XTLocalBranch,
                    upstreamBranch: XTRemoteBranch) ->(ahead: Int,
    behind: Int)?
}

public protocol FileStatusDetection: class
{
  associatedtype ID: OID

  func changes(for sha: String, parent parentOID: ID) -> [FileChange]
}

public protocol FileDiffing: class
{
  associatedtype ID: OID
  
  func diffMaker(forFile file: String,
                 commitOID: ID,
                 parentOID: ID?) -> XTDiffMaker?
  func diff(for path: String,
            commitSHA sha: String,
            parentOID: ID?) -> XTDiffDelta?
  func stagedDiff(file: String) -> XTDiffMaker?
  func unstagedDiff(file: String) -> XTDiffMaker?
}

public protocol FileContents: class
{
  associatedtype C: CommitType

  func fileBlob(ref: String, path: String) -> GTBlob?
  func stagedBlob(file: String) -> GTBlob?
  func contentsOfFile(path: String, at commit: C) -> Data?
  func contentsOfStagedFile(path: String) -> Data?
}

public protocol SubmoduleManagement: class
{
  func submodules() -> [XTSubmodule]
  func addSubmodule(path: String, url: String) throws
}
