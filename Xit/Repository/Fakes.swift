import Foundation
import Combine

extension FakeCommit
{
  init(branchHead branch: any Branch)
  {
    self.init(parentOIDs: [],
              message: branch.referenceName.name,
              isSigned: false,
              id: branch.oid!)
  }
}

class FakeRemote: Remote
{
  typealias RefSpec = NullRefSpec

  var name: String?
  var urlString: String?
  var pushURLString: String? { urlString }
  
  var refSpecs: AnyCollection<NullRefSpec>
  { AnyCollection([NullRefSpec]()) }

  func rename(_ name: String) throws {}
  func updateURLString(_ URLString: String?) throws {}
  func updatePushURLString(_ URLString: String?) throws {}

  func withConnection<T>(direction: RemoteConnectionDirection,
                         callbacks: RemoteCallbacks,
                         action: (ConnectedRemote) throws -> T) throws -> T
  {
    try action(NullConnectedRemote())
  }
}

class FakeLocalBranch: LocalBranch
{
  var referenceName: LocalBranchRefName { .init(rawValue: name)! }
  var trackingBranchName: (any ReferenceName)?
  var trackingBranch: FakeRemoteBranch?
  var name: String
  var shortName: String { referenceName.name }
  var oid: GitOID?
  var targetCommit: (any Commit)?
  
  init(name: String, oid: GitOID = .random())
  {
    self.name = RefPrefixes.heads +/ name
    self.oid = oid
  }

  func setTrackingBranch(_ branch: (any ReferenceName)?) throws
  { trackingBranchName = branch }
}

class FakeRemoteBranch: RemoteBranch
{
  var referenceName: RemoteBranchRefName { .init(rawValue: name)! }
  var remoteName: String?
  var name: String
  public var shortName: String
  { name.droppingPrefix(RefPrefixes.remotes) }
  var oid: GitOID?
  var targetCommit: (any Commit)?
  
  init(remoteName: String, name: String, oid: GitOID = .random())
  {
    self.name = RefPrefixes.remotes +/ remoteName +/ name
    self.remoteName = remoteName
    self.oid = oid
  }
}

class FakeRepoController: RepositoryController
{
  var repository: BasicRepository
  var queue: TaskQueue = TaskQueue(id: "testing")
  var cache: RepositoryCache = .init()

  var configPublisher: AnyPublisher<Void, Never> { Empty().eraseToAnyPublisher() }
  var headPublisher: AnyPublisher<Void, Never> { Empty().eraseToAnyPublisher() }
  var indexPublisher: AnyPublisher<Void, Never> { Empty().eraseToAnyPublisher() }
  var refLogPublisher: AnyPublisher<Void, Never> { Empty().eraseToAnyPublisher() }
  var refsPublisher: AnyPublisher<Void, Never> { Empty().eraseToAnyPublisher() }
  var stashPublisher: AnyPublisher<Void, Never> { Empty().eraseToAnyPublisher() }
  var progressPublisher: AnyPublisher<ProgressValue, Never>
  { Empty().eraseToAnyPublisher() }
  var workspacePublisher: AnyPublisher<[String], Never>
  { Empty().eraseToAnyPublisher() }

  init(repository: FakeRepo)
  {
    self.repository = repository
    repository.controller = self
  }

  func invalidateIndex() {}
  func waitForQueue() {}

  func post(progress: Float, total: Float) {}
  func indexChanged() {}
  func refsChanged() {}
}
