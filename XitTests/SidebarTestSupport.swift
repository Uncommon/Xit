import Combine
import Foundation

/// Shared repository doubles for sidebar-focused tests.
///
/// These live in `XitTests` instead of the app target so the test target does
/// not depend on debug-only fake files remaining compiled into `Xit`.
final class TestRepositoryPublisher: RepositoryPublishing
{
  let configSubject = PassthroughSubject<Void, Never>()
  let headSubject = PassthroughSubject<Void, Never>()
  let indexSubject = PassthroughSubject<Void, Never>()
  let refLogSubject = PassthroughSubject<Void, Never>()
  let refsSubject = PassthroughSubject<Void, Never>()
  let stashSubject = PassthroughSubject<Void, Never>()
  let progressSubject = PassthroughSubject<ProgressValue, Never>()
  let workspaceSubject = PassthroughSubject<[String], Never>()

  var configPublisher: AnyPublisher<Void, Never>
  { configSubject.eraseToAnyPublisher() }

  var headPublisher: AnyPublisher<Void, Never>
  { headSubject.eraseToAnyPublisher() }

  var indexPublisher: AnyPublisher<Void, Never>
  { indexSubject.eraseToAnyPublisher() }

  var refLogPublisher: AnyPublisher<Void, Never>
  { refLogSubject.eraseToAnyPublisher() }

  var refsPublisher: AnyPublisher<Void, Never>
  { refsSubject.eraseToAnyPublisher() }

  var stashPublisher: AnyPublisher<Void, Never>
  { stashSubject.eraseToAnyPublisher() }

  var progressPublisher: AnyPublisher<ProgressValue, Never>
  { progressSubject.eraseToAnyPublisher() }

  var workspacePublisher: AnyPublisher<[String], Never>
  { workspaceSubject.eraseToAnyPublisher() }

  func post(progress: Float, total: Float)
  {
    progressSubject.send((current: progress, total: total))
  }

  func indexChanged()
  {
    indexSubject.send()
  }

  func refsChanged()
  {
    refsSubject.send()
  }
}

final class TestConnectedRemote: ConnectedRemote
{
  var defaultBranch: String? { nil }

  func referenceAdvertisements() throws -> [RemoteHead] { [] }
}

struct TestRefSpec: RefSpec
{
  let source: String
  let destination: String
  let stringValue: String
  let force: Bool
  let direction: RemoteConnectionDirection

  init(source: String = "",
       destination: String = "",
       stringValue: String = "",
       force: Bool = false,
       direction: RemoteConnectionDirection = .fetch)
  {
    self.source = source
    self.destination = destination
    self.stringValue = stringValue
    self.force = force
    self.direction = direction
  }

  func sourceMatches(refName: String) -> Bool { false }
  func destinationMatches(refName: String) -> Bool { false }
  func transformToTarget(name: String) -> String? { nil }
  func transformToSource(name: String) -> String? { nil }
}

final class TestRemote: Remote
{
  var name: String?
  var urlString: String?
  var pushURLString: String?
  var refSpecs: AnyCollection<TestRefSpec> { AnyCollection([]) }

  init(name: String, urlString: String? = nil)
  {
    self.name = name
    self.urlString = urlString ?? "https://example.com/\(name).git"
    self.pushURLString = self.urlString
  }

  func rename(_ name: String) throws
  {
    self.name = name
  }

  func updateURLString(_ URLString: String?) throws
  {
    urlString = URLString
  }

  func updatePushURLString(_ URLString: String?) throws
  {
    pushURLString = URLString
  }

  func withConnection<T>(direction: RemoteConnectionDirection,
                         callbacks: RemoteCallbacks,
                         action: (any ConnectedRemote) throws -> T) throws -> T
  {
    try action(TestConnectedRemote())
  }
}

final class TestRemoteManager: RemoteManagement
{
  typealias Remote = TestRemote

  var remoteNameList: [String]

  init(remoteNames: [String])
  {
    self.remoteNameList = remoteNames
  }

  func remoteNames() -> [String]
  {
    remoteNameList
  }

  func remote(named name: String) -> TestRemote?
  {
    guard remoteNameList.contains(name) else { return nil }
    return TestRemote(name: name)
  }

  func addRemote(named name: String, url: URL) throws
  {
    remoteNameList.append(name)
  }

  func deleteRemote(named name: String) throws
  {
    remoteNameList.removeAll { $0 == name }
  }

  func push(branches: [LocalBranchRefName],
            remote: TestRemote,
            callbacks: RemoteCallbacks) throws {}

  func fetch(remote: TestRemote, options: FetchOptions) throws {}

  func pull(branch: any Branch,
            remote: TestRemote,
            options: FetchOptions) throws {}
}

final class TestRemoteBranch: RemoteBranch
{
  var referenceName: RemoteBranchRefName
  var oid: GitOID?
  var targetCommit: (any Commit)?
  var remoteName: String?

  init(remoteName: String, name: String, oid: GitOID = .random())
  {
    self.referenceName = .init(remote: remoteName, branch: name)!
    self.remoteName = remoteName
    self.oid = oid
  }
}

final class TestLocalBranch: LocalBranch
{
  typealias RemoteBranch = TestRemoteBranch

  var referenceName: LocalBranchRefName
  var trackingBranchName: (any ReferenceName)?
  var trackingBranch: TestRemoteBranch?
  var oid: GitOID?
  var targetCommit: (any Commit)?

  init(name: String,
       oid: GitOID = .random(),
       trackingBranch: TestRemoteBranch? = nil)
  {
    self.referenceName = .named(name)!
    self.oid = oid
    self.trackingBranch = trackingBranch
    self.trackingBranchName = trackingBranch?.referenceName
  }

  func setTrackingBranch(_ branch: (any ReferenceName)?) throws
  {
    trackingBranchName = branch
    trackingBranch = nil
  }
}

final class TestBrancher: Branching
{
  typealias LocalBranch = TestLocalBranch
  typealias RemoteBranch = TestRemoteBranch

  var localBranchArray: [TestLocalBranch]
  var remoteBranchArray: [TestRemoteBranch]
  var currentBranch: LocalBranchRefName?

  var localBranches: AnySequence<TestLocalBranch>
  { AnySequence(localBranchArray) }

  var remoteBranches: AnySequence<TestRemoteBranch>
  { AnySequence(remoteBranchArray) }

  init(localBranches: [TestLocalBranch] = [],
       remoteBranches: [TestRemoteBranch] = [],
       currentBranch: LocalBranchRefName? = nil)
  {
    self.localBranchArray = localBranches
    self.remoteBranchArray = remoteBranches
    self.currentBranch = currentBranch
  }

  func createBranch(named name: LocalBranchRefName,
                    target: some ReferenceName) throws -> TestLocalBranch?
  {
    let branch = TestLocalBranch(name: name.name)
    localBranchArray.append(branch)
    return branch
  }

  func rename(branch: LocalBranchRefName, to: LocalBranchRefName) throws
  {
    guard let existing = localBranchArray.first(where: {
      $0.referenceName == branch
    }) else { return }
    existing.referenceName = to
  }

  func deleteBranch(_ name: LocalBranchRefName) throws
  {
    localBranchArray.removeAll { $0.referenceName == name }
  }

  func localBranch(named refName: LocalBranchRefName) -> TestLocalBranch?
  {
    localBranchArray.first { $0.referenceName == refName }
  }

  func remoteBranch(named name: String) -> TestRemoteBranch?
  {
    remoteBranchArray.first {
      $0.referenceName.name == name || $0.referenceName.fullPath == name
    }
  }

  func remoteBranch(named name: String, remote: String) -> TestRemoteBranch?
  {
    remoteBranchArray.first {
      $0.referenceName.name == name && $0.remoteName == remote
    }
  }

  func localBranch(tracking remoteBranch: TestRemoteBranch) -> TestLocalBranch?
  {
    localBranchArray.first {
      $0.trackingBranch?.referenceName == remoteBranch.referenceName
    }
  }

  func localTrackingBranch(forBranch branch: RemoteBranchRefName) -> TestLocalBranch?
  {
    localBranchArray.first { $0.trackingBranch?.referenceName == branch }
  }

  func reset(toCommit target: any Commit, mode: ResetMode) throws {}
}

final class TestFileStatusDetector: FileStatusDetection
{
  func changes(for oid: GitOID, parent parentOID: GitOID?) -> [FileChange] { [] }
  func stagedChanges() -> [FileChange] { [] }
  func amendingStagedChanges() -> [FileChange] { [] }
  func unstagedChanges(showIgnored: Bool,
                       recurseUntracked: Bool,
                       useCache: Bool) -> [FileChange]
  { [] }
  func amendingStagedStatus(for path: String) throws -> DeltaStatus { .unmodified }
  func amendingUnstagedStatus(for path: String) throws -> DeltaStatus { .unmodified }
  func stagedStatus(for path: String) throws -> DeltaStatus { .unmodified }
  func unstagedStatus(for path: String) throws -> DeltaStatus { .unmodified }
  func status(file: String) throws -> (DeltaStatus, DeltaStatus)
  { (.unmodified, .unmodified) }
  func isIgnored(path: String) -> Bool { false }
}

struct TestTag: Tag
{
  var name: TagRefName
  var signature: Signature?
  var targetOID: GitOID?
  var commit: FakeCommit?
  var message: String?
  var type: TagType { message == nil ? .lightweight : .annotated }
  var isSigned = false

  static func == (lhs: TestTag, rhs: TestTag) -> Bool
  {
    lhs.name == rhs.name
  }
}

final class TestTagger: Tagging
{
  var tagList: [TestTag]

  init(tagList: [TestTag] = [])
  {
    self.tagList = tagList
  }

  func tags() throws -> [TestTag]
  {
    tagList
  }

  func tag(named name: TagRefName) -> TestTag?
  {
    tagList.first { $0.name == name }
  }

  func createTag(name: String, targetOID: GitOID, message: String?) throws {}
  func createLightweightTag(name: String, targetOID: GitOID) throws {}
  func deleteTag(name: TagRefName) throws {}
}

final class TestStash: Stash
{
  var message: String?
  var mainCommit: FakeCommit?
  var indexCommit: FakeCommit?
  var untrackedCommit: FakeCommit?

  init(message: String? = nil, id: GitOID = .random())
  {
    self.message = message
    self.mainCommit = FakeCommit(parentOIDs: [], message: message,
                                 isSigned: false, id: id)
  }

  func indexChanges() -> [FileChange] { [] }
  func workspaceChanges() -> [FileChange] { [] }
  func stagedDiffForFile(_ path: String) -> PatchMaker.PatchResult? { nil }
  func unstagedDiffForFile(_ path: String) -> PatchMaker.PatchResult? { nil }
}

final class TestStasher: Stashing
{
  var stashArray: [TestStash]
  var stashes: AnyRandomAccessCollection<TestStash> { .init(stashArray) }

  init(stashes: [TestStash] = [])
  {
    self.stashArray = stashes
  }

  func stash(index: UInt, message: String?) -> TestStash
  {
    stashArray[Int(index)]
  }

  func popStash(index: UInt) throws {}
  func applyStash(index: UInt) throws {}
  func dropStash(index: UInt) throws {}
  func commitForStash(at index: UInt) -> FakeCommit?
  {
    stashArray[Int(index)].mainCommit
  }
  func saveStash(name: String?,
                 keepIndex: Bool,
                 includeUntracked: Bool,
                 includeIgnored: Bool) throws {}
}

struct TestSubmodule: Submodule
{
  var name: String
  var path: String
  var url: URL?
  var ignoreRule: SubmoduleIgnore = .unspecified
  var updateStrategy: SubmoduleUpdate = .default
  var recurse: SubmoduleRecurse = .yes

  func update(initialize: Bool, callbacks: RemoteCallbacks) throws {}
}

final class TestSubmoduleManager: SubmoduleManagement
{
  var submoduleList: [any Submodule]

  init(submodules: [any Submodule] = [])
  {
    self.submoduleList = submodules
  }

  func submodules() -> [any Submodule]
  {
    submoduleList
  }

  func addSubmodule(path: String, url: String) throws {}
}
