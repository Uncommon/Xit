// URL and UUID should be Sendable
@preconcurrency import Foundation
import Siesta
@testable import Xit

struct FakeCommit: Commit
{
  var parentOIDs: [any OID]
  var message: String?
  var authorSig: Signature?
  var committerSig: Signature?
  var email: String?
  var tree: (any Tree)?
  var id: any OID
  var isSigned: Bool { false }

  init(parentOIDs: [any OID],
       message: String? = nil,
       authorSig: Signature? = nil,
       committerSig: Signature? = nil,
       email: String? = nil,
       tree: (any Tree)? = nil,
       oid: String)
  {
    self.parentOIDs = parentOIDs
    self.message = message
    self.authorSig = authorSig
    self.committerSig = committerSig
    self.email = email
    self.tree = tree
    self.id = oid
  }

  func getTrailers() -> [(String, [String])] { [] }
}

extension FakeCommit
{
  init(branchHead branch: any Branch)
  {
    self.parentOIDs = []
    self.message = branch.shortName
    self.id = branch.oid!
  }
}

class FakeConnectedRemote: ConnectedRemote
{
  var defaultBranch: String? { nil }
  
  func referenceAdvertisements() throws -> [RemoteHead] { [] }
}

class FakeRemote: Remote
{
  var name: String?
  var urlString: String?
  var pushURLString: String? { urlString }
  
  var refSpecs: AnyCollection<any RefSpec> { AnyCollection([any RefSpec]()) }
  
  func rename(_ name: String) throws {}
  func updateURLString(_ URLString: String?) throws {}
  func updatePushURLString(_ URLString: String?) throws {}

  func withConnection<T>(direction: RemoteConnectionDirection,
                         callbacks: RemoteCallbacks,
                         action: (ConnectedRemote) throws -> T) throws -> T
  {
    try action(FakeConnectedRemote())
  }
}

class FakeStash: Stash
{
  var message: String? = nil
  var mainCommit: (any Commit)? = nil
  var indexCommit: (any Commit)? = nil
  var untrackedCommit: (any Commit)? = nil
  
  func indexChanges() -> [FileChange] { [] }
  func workspaceChanges() -> [FileChange] { [] }
  func stagedDiffForFile(_ path: String) -> PatchMaker.PatchResult?
  { nil }
  func unstagedDiffForFile(_ path: String) -> PatchMaker.PatchResult?
  { nil }
}

struct FakePullRequest: PullRequest
{
  var serviceID: UUID
  var availableActions: PullRequestActions
  var sourceBranch: String
  var sourceRepo: URL?
  var displayName: String
  var id: String
  var authorName: String?
  var status: PullRequestStatus
  var webURL: URL?
  
  func isApproved(by userID: String) -> Bool { false }
  
  func reviewerStatus(userID: String) -> PullRequestApproval
  { .unreviewed }
  
  mutating func setReviewerStatus(userID: String, status: PullRequestApproval) {}
}

class FakePRService : PullRequestService
{
  init() {}
  
  func getPullRequests() -> [any PullRequest] { [] }
  func approve(request: PullRequest) {}
  func unapprove(request: PullRequest) {}
  func needsWork(request: PullRequest) {}
  func merge(request: PullRequest) {}
  
  func match(remote: any Remote) -> Bool { true }
  
  var userID: String = ""
}

class FakeLocalBranch: LocalBranch
{
  var trackingBranchName: String?
  var trackingBranch: (any RemoteBranch)?
  var name: String
  var shortName: String { strippedName }
  var oid: (any OID)?
  var targetCommit: (any Commit)?
  
  init(name: String)
  {
    self.name = RefPrefixes.heads +/ name
    self.oid = UUID().uuidString
  }
}

class FakeRemoteBranch: RemoteBranch
{
  var remoteName: String?
  var name: String
  public var shortName: String
  { name.droppingPrefix(RefPrefixes.remotes) }
  var oid: (any OID)?
  var targetCommit: (any Commit)?
  
  init(remoteName: String, name: String)
  {
    self.name = RefPrefixes.remotes +/ remoteName +/ name
    self.remoteName = remoteName
    self.oid = UUID().uuidString
  }
}

class FakeRepoController: RepositoryController
{
  var repository: BasicRepository

  var queue: TaskQueue = TaskQueue(id: "testing")

  var cachedStagedChanges: [FileChange]? = nil
  var cachedAmendChanges: [FileChange]? = nil
  var cachedUnstagedChanges: [FileChange]? = nil
  var cachedBranches: [String : GitBranch] = [:]

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
  
  func sha(forRef: String) -> String? { nil }
  
  func tags() throws -> [any Tag] { [] }
  func graphBetween(localBranch: LocalBranch, upstreamBranch: RemoteBranch)
    -> (ahead: Int, behind: Int)?
  { nil }
  func localBranch(named name: String) -> (any LocalBranch)? { nil }
  func remoteBranch(named name: String, remote: String) -> (any RemoteBranch)?
  { nil }
  func reference(named name: String) -> (any Reference)? { nil }
  func refs(at sha: String) -> [String] { [] }
  func allRefs() -> [String] { [] }
  func rebuildRefsIndex() {}
  func createCommit(with tree: Tree, message: String, parents: [Commit],
                    updatingReference refName: String) throws -> any OID
  { "" }
  func oid(forRef: String) -> (any OID)? { nil }

  var repoURL: URL { URL(fileURLWithPath: "") }
  
  func isTextFile(_ path: String, context: FileContext) -> Bool { false }
  func fileBlob(ref: String, path: String) -> Blob? { nil }
  func stagedBlob(file: String) -> Blob? { nil }
  func contentsOfFile(path: String, at commit: Commit) -> Data? { nil }
  func contentsOfStagedFile(path: String) -> Data? { nil }
  func fileURL(_ file: String) -> URL { URL(fileURLWithPath: "") }
  
  func diffMaker(forFile file: String, commitOID: any OID, parentOID: (any OID)?)
    -> PatchMaker.PatchResult?
  { nil }
  func diff(for path: String, commitSHA sha: String, parentOID: (any OID)?) -> DiffDelta?
  { nil }
  func stagedDiff(file: String) -> PatchMaker.PatchResult? { nil }
  func unstagedDiff(file: String) -> PatchMaker.PatchResult? { nil }
  func amendingStagedDiff(file: String) -> PatchMaker.PatchResult?{ nil }
  
  func blame(for path: String, from startOID: (any OID)?, to endOID: (any OID)?) -> (any Blame)?
  { nil }
  func blame(for path: String, data fromData: Data?, to endOID: (any OID)?) -> (any Blame)?
  { nil }
  
  var index: (any StagingIndex)? { nil }
  
  func stage(file: String) throws {}
  func unstage(file: String) throws {}
  func amendStage(file: String) throws {}
  func amendUnstage(file: String) throws {}
  func revert(file: String) throws {}
  func stageAllFiles() throws {}
  func unstageAllFiles() throws {}
  func patchIndexFile(path: String, hunk: DiffHunk, stage: Bool) throws {}
  func status(file: String) throws -> (DeltaStatus, DeltaStatus)
  { (.unmodified, .unmodified) }

  func changes(for sha: String, parent parentOID: (any OID)?) -> [FileChange]
  { [] }
  func stagedChanges() -> [FileChange] { [] }
  func unstagedChanges(showIgnored: Bool,
                       recurseUntracked: Bool,
                       useCache: Bool) -> [FileChange]
  { [] }
  func amendingStagedChanges() -> [FileChange] { [] }
  func amendingStagedStatus(for path: String) throws -> DeltaStatus
  { .unmodified }
  func amendingUnstagedStatus(for path: String) throws -> DeltaStatus
  { .unmodified }
  func stagedStatus(for path: String) throws -> DeltaStatus
  { .unmodified }
  func unstagedStatus(for path: String) throws -> DeltaStatus
  { .unmodified }
  func isIgnored(path: String) -> Bool { false }
}
