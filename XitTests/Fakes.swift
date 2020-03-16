import Foundation
import Siesta
@testable import Xit

struct FakeCommit: Commit
{
  var parentOIDs: [OID]
  var message: String?
  var authorSig: Signature?
  var committerSig: Signature?
  var email: String?
  var tree: Tree?
  var oid: OID
}

extension FakeCommit
{
  init(branchHead branch: Branch)
  {
    self.parentOIDs = []
    self.message = branch.shortName
    self.oid = branch.oid!
  }
}

class FakeRemote: Remote
{
  var name: String?
  var urlString: String?
  var pushURLString: String? { return urlString }
  
  var refSpecs: AnyCollection<RefSpec> { return AnyCollection([RefSpec]()) }
  
  func rename(_ name: String) throws {}
  func updateURLString(_ URLString: String?) throws {}
  func updatePushURLString(_ URLString: String?) throws {}

  func withConnection(direction: RemoteConnectionDirection,
                      callbacks: RemoteCallbacks,
                      action: () throws -> Void) throws
  {
    try action()
  }
}

class FakeStash: Stash
{
  var message: String? = nil
  var mainCommit: Commit? = nil
  var indexCommit: Commit? = nil
  var untrackedCommit: Commit? = nil
  
  func indexChanges() -> [FileChange] { return [] }
  func workspaceChanges() -> [FileChange] { return [] }
  func stagedDiffForFile(_ path: String) -> PatchMaker.PatchResult?
  { return nil }
  func unstagedDiffForFile(_ path: String) -> PatchMaker.PatchResult?
  { return nil }
}

struct FakePullRequest: PullRequest
{
  var service: PullRequestService
  var availableActions: PullRequestActions
  var sourceBranch: String
  var sourceRepo: URL?
  var displayName: String
  var id: String
  var authorName: String?
  var status: PullRequestStatus
  var webURL: URL?
  
  func isApproved(by userID: String) -> Bool { return false }
  
  func reviewerStatus(userID: String) -> PullRequestApproval
  { return .unreviewed }
  
  mutating func setReviewerStatus(userID: String, status: PullRequestApproval) {}
}

class FakePRService : PullRequestService
{
  init() {}
  
  func getPullRequests(callback: @escaping ([PullRequest]) -> Void)
  {
    callback([])
  }
  
  func approve(request: PullRequest, onSuccess: @escaping () -> Void,
               onFailure: @escaping (Siesta.RequestError) -> Void)
  {
    onSuccess()
  }
  
  func unapprove(request: PullRequest, onSuccess: @escaping () -> Void,
                 onFailure: @escaping (Siesta.RequestError) -> Void)
  {
    onSuccess()
  }
  
  func needsWork(request: PullRequest, onSuccess: @escaping () -> Void,
                 onFailure: @escaping (Siesta.RequestError) -> Void)
  {
    onSuccess()
  }
  
  func merge(request: PullRequest) {}
  
  func match(remote: Remote) -> Bool { return true }
  
  var userID: String = ""
}

class FakeLocalBranch: LocalBranch
{
  var trackingBranchName: String?
  var trackingBranch: RemoteBranch?
  var name: String
  var shortName: String { return strippedName }
  var oid: OID?
  var targetCommit: Commit?
  
  init(name: String)
  {
    self.name = RefPrefixes.heads +/ name
    self.oid = StringOID(sha: UUID().uuidString)
  }
}

class FakeRemoteBranch: RemoteBranch
{
  var remoteName: String?
  var name: String
  public var shortName: String
  { return name.droppingPrefix(RefPrefixes.remotes) }
  var oid: OID?
  var targetCommit: Commit?
  
  init(remoteName: String, name: String)
  {
    self.name = RefPrefixes.remotes +/ remoteName +/ name
    self.remoteName = remoteName
    self.oid = StringOID(sha: UUID().uuidString)
  }
}

class FakeRepoController: RepositoryController
{
  var repository: BasicRepository

  var queue: TaskQueue = TaskQueue(id: "testing")

  var cachedStagedChanges: [FileChange]? = nil
  var cachedAmendChanges: [FileChange]? = nil
  var cachedUnstagedChanges: [FileChange]? = nil

  func invalidateIndex() {}

  init(repository: FakeRepo)
  {
    self.repository = repository
    repository.controller = self
  }

  func waitForQueue() {}
}

class FakeFileChangesRepo: FileChangesRepo
{
  var controller: RepositoryController?

  var headRef: String? = nil
  var currentBranch: String? = nil
  
  func sha(forRef: String) -> String? { return nil }
  
  func tags() throws -> [Tag] { return [] }
  func graphBetween(localBranch: LocalBranch, upstreamBranch: RemoteBranch)
    -> (ahead: Int, behind: Int)?
  { return nil }
  func localBranch(named name: String) -> LocalBranch? { return nil }
  func remoteBranch(named name: String, remote: String) -> RemoteBranch?
  { return nil }
  func reference(named name: String) -> Reference? { return nil }
  func refs(at sha: String) -> [String] { return [] }
  func allRefs() -> [String] { [] }
  func rebuildRefsIndex() {}
  func createCommit(with tree: Tree, message: String, parents: [Commit],
                    updatingReference refName: String) throws -> OID
  { return StringOID(sha: "") }
  func oid(forRef: String) -> OID? { nil }

  var repoURL: URL { return URL(fileURLWithPath: "") }
  
  func isTextFile(_ path: String, context: FileContext) -> Bool{ return false }
  func fileBlob(ref: String, path: String) -> Blob? { return nil }
  func stagedBlob(file: String) -> Blob? { return nil }
  func contentsOfFile(path: String, at commit: Commit) -> Data? { return nil }
  func contentsOfStagedFile(path: String) -> Data? { return nil }
  func fileURL(_ file: String) -> URL { return URL(fileURLWithPath: "") }
  
  func diffMaker(forFile file: String, commitOID: OID, parentOID: OID?)
    -> PatchMaker.PatchResult?
  { return nil }
  func diff(for path: String, commitSHA sha: String, parentOID: OID?) -> DiffDelta?
  { return nil }
  func stagedDiff(file: String) -> PatchMaker.PatchResult? { return nil }
  func unstagedDiff(file: String) -> PatchMaker.PatchResult? { return nil }
  func amendingStagedDiff(file: String) -> PatchMaker.PatchResult?{ return nil }
  
  func blame(for path: String, from startOID: OID?, to endOID: OID?) -> Blame?
  { return nil }
  func blame(for path: String, data fromData: Data?, to endOID: OID?) -> Blame?
  { return nil }
  
  var index: StagingIndex? { return nil }
  
  func stage(file: String) throws {}
  func unstage(file: String) throws {}
  func amendStage(file: String) throws {}
  func amendUnstage(file: String) throws {}
  func revert(file: String) throws {}
  func stageAllFiles() throws {}
  func unstageAllFiles() throws {}
  
  func changes(for sha: String, parent parentOID: OID?) -> [FileChange]
  { return [] }
  func stagedChanges() -> [FileChange] { return [] }
  func unstagedChanges(showIgnored: Bool) -> [FileChange] { return [] }
  func amendingStagedChanges() -> [FileChange] { return [] }
  func amendingStagedStatus(for path: String) throws -> DeltaStatus
  { return .unmodified }
  func amendingUnstagedStatus(for path: String) throws -> DeltaStatus
  { return .unmodified }
  func stagedStatus(for path: String) throws -> DeltaStatus
  { return .unmodified }
  func unstagedStatus(for path: String) throws -> DeltaStatus
  { return .unmodified }
  func isIgnored(path: String) -> Bool { return false }
}
