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

public protocol SubmoduleManagement: class
{
  func submodules() -> [XTSubmodule]
  func addSubmodule(path: String, url: String) throws
}
