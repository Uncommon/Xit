// URL and UUID should be Sendable
@preconcurrency import Foundation
import Siesta
@testable import Xit

extension StringCommit
{
  init(branchHead branch: any Branch)
  {
    self.init(parentOIDs: [],
              message: branch.shortName,
              isSigned: false,
              id: .init(rawValue: branch.oid!.sha))
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
  
  var refSpecs: AnyCollection<FakeRefSpec>
  { return AnyCollection([FakeRefSpec]()) }

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

struct FakeRefSpec: RefSpec
{
  let source: String
  let destination: String
  let stringValue: String
  let force: Bool
  let direction: Xit.RemoteConnectionDirection

  func sourceMatches(refName: String) -> Bool { false }
  func destinationMatches(refName: String) -> Bool { false }
  func transformToTarget(name: String) -> String? { nil }
  func transformToSource(name: String) -> String? { nil }
}

class FakeStash: Stash
{
  typealias ID = StringOID
  var message: String? = nil
  var mainCommit: StringCommit? = nil
  var indexCommit: StringCommit? = nil
  var untrackedCommit: StringCommit? = nil
  
  func indexChanges() -> [FileChange] { [] }
  func workspaceChanges() -> [FileChange] { [] }
  func stagedDiffForFile(_ path: String) -> PatchMaker.PatchResult?
  { nil }
  func unstagedDiffForFile(_ path: String) -> PatchMaker.PatchResult?
  { nil }
}

struct FakeTag: Tag
{
  var targetOID: StringOID?
  var commit: Xit.StringCommit?
  var name: String
  var signature: Xit.Signature?
  var message: String?
  var type: Xit.TagType
  var isSigned: Bool
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
  typealias ObjectIdentifier = StringOID
  typealias Commit = StringCommit

  var trackingBranchName: String?
  var trackingBranch: FakeRemoteBranch?
  var name: String
  var shortName: String { strippedName }
  var oid: StringOID?
  var targetCommit: StringCommit?

  init(name: String)
  {
    self.name = RefPrefixes.heads +/ name
    self.oid = StringOID(rawValue: UUID().uuidString)
  }
}

class FakeRemoteBranch: RemoteBranch
{
  typealias ObjectIdentifier = StringOID
  typealias Commit = StringCommit

  var remoteName: String?
  var name: String
  public var shortName: String
  { name.droppingPrefix(RefPrefixes.remotes) }
  var oid: StringOID?
  var targetCommit: StringCommit?

  init(remoteName: String, name: String)
  {
    self.name = RefPrefixes.remotes +/ remoteName +/ name
    self.remoteName = remoteName
    self.oid = StringOID(rawValue: UUID().uuidString)
  }
}

struct FakeReference: Reference
{
  var targetOID: StringOID?
  var peeledTargetOID: StringOID?
  var symbolicTargetName: String?
  var type: ReferenceType
  var name: String

  func setTarget(_ newOID: StringOID, logMessage: String) {}
  func resolve() -> FakeReference? { nil }
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
