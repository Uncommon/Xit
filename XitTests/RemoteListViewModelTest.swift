import Foundation
import Testing
@testable import Xit

struct RemoteListViewModelTest
{
  enum WaitError: Error
  {
    case remotesStreamEnded
    case timedOut
  }

  @Test
  func singleRemote() throws
  {
    let remoteName = "origin"
    let manager = TestRemoteManager(remoteNames: [remoteName])
    let brancher = TestBrancher(remoteBranches: [
      .init(remoteName: remoteName, name: "main")
    ])
    let model = RemoteListViewModel(manager: manager,
                                    brancher: brancher,
                                    publisher: TestRepositoryPublisher())
    
    try #require(model.remotes.count == 1)
    #expect(model.remotes[0].name == remoteName)
    #expect(model.remotes[0].branches.count == 1)
  }
  
  @Test
  func twoRemotesWithBranches() throws
  {
    let remoteNames = ["origin1", "origin2"]
    let branches1 = ["main1", "work/things1"]
    let branches2 = ["feature", "main2", "work/things2"]
    let manager = TestRemoteManager(remoteNames: remoteNames)
    let brancher = TestBrancher(remoteBranches: branches1.map {
      .init(remoteName: remoteNames[0], name: $0)
    } + branches2.map {
      .init(remoteName: remoteNames[1], name: $0)
    })
    let model = RemoteListViewModel(manager: manager,
                                    brancher: brancher,
                                    publisher: TestRepositoryPublisher())
    
    try #require(model.remotes.count == 2)
    #expect(model.remotes[0].name == remoteNames[0])
    #expect(model.remotes[1].name == remoteNames[1])
    #expect(model.remotes[0].branches.count == 2)
    #expect(model.remotes[1].branches.count == 3)
  }
  
  @Test
  func superSubBranch() throws
  {
    let remoteName = "origin"
    let manager = TestRemoteManager(remoteNames: [remoteName])
    let brancher = TestBrancher(remoteBranches: [
      .init(remoteName: remoteName, name: "main"),
      .init(remoteName: remoteName, name: "superBranch"),
      .init(remoteName: remoteName, name: "superBranch/subBranch"),
    ])
    let model = RemoteListViewModel(manager: manager,
                                    brancher: brancher,
                                    publisher: TestRepositoryPublisher())

    try #require(model.remotes.count == 1)
    #expect(model.remotes[0].name == remoteName)
    try #require(model.remotes[0].branches.count == 2)
    #expect(model.remotes[0].branches[0].item?.name == "origin/main")
    #expect(model.remotes[0].branches[1].item?.name == "origin/superBranch")
    #expect(model.remotes[0].branches[1].children?.count == 1)
  }
  
  @Test
  func remoteSearch() throws
  {
    let remoteNames = ["genesis", "origin"]
    let branches1 = ["main1", "work/things1"]
    let branches2 = ["feature", "main2", "work/things2"]
    let manager = TestRemoteManager(remoteNames: remoteNames)
    let brancher = TestBrancher(remoteBranches: branches1.map {
      .init(remoteName: remoteNames[0], name: $0)
    } + branches2.map {
      .init(remoteName: remoteNames[1], name: $0)
    })
    let model = RemoteListViewModel(manager: manager,
                                    brancher: brancher,
                                    publisher: TestRepositoryPublisher())

    model.searchScope = .remotes
    // Call filterChanged directly instead of trying to wait for the debounce
    model.filterChanged(String(remoteNames[0].prefix(3)))
    try #require(model.remotes.count == 1)
    #expect(model.remotes[0].name == remoteNames[0])
    
    let branchNames = model.remotes[0].branches.map { $0.path }
    
    #expect(branchNames == [
      "refs/remotes/genesis/main1",
      "refs/remotes/genesis/work",
    ])
  }
  
  @Test
  func branchSearch() throws
  {
    let remoteNames = ["genesis", "origin"]
    let branches1 = ["main1", "work/things1"]
    let branches2 = ["feature", "main2", "work/things2"]
    let manager = TestRemoteManager(remoteNames: remoteNames)
    let brancher = TestBrancher(remoteBranches: branches1.map {
      .init(remoteName: remoteNames[0], name: $0)
    } + branches2.map {
      .init(remoteName: remoteNames[1], name: $0)
    })
    let model = RemoteListViewModel(manager: manager,
                                    brancher: brancher,
                                    publisher: TestRepositoryPublisher())

    model.searchScope = .branches
    // Call filterChanged directly instead of trying to wait for the debounce
    model.filterChanged("things")
    
    try #require(model.remotes.count == 2)
    #expect(model.remotes[0].name == "genesis")
    #expect(model.remotes[1].name == "origin")
    try #require(model.remotes[0].branches.count == 1)
    try #require(model.remotes[1].branches.count == 1)

    let workBranch1 = model.remotes[0].branches[0]
    
    #expect(workBranch1.path == "refs/remotes/genesis/work")
    #expect(workBranch1.children?.first?.path == "refs/remotes/genesis/work/things1")
    
    let workBranch2 = model.remotes[1].branches[0]
    
    #expect(workBranch2.path == "refs/remotes/origin/work")
    #expect(workBranch2.children?.first?.path == "refs/remotes/origin/work/things2")
  }

  @Test
  @MainActor
  func refsPublisherRefreshesBranchHierarchy() async throws
  {
    let publisher = TestRepositoryPublisher()
    let manager = TestRemoteManager(remoteNames: ["origin"])
    let brancher = TestBrancher(remoteBranches: [
      .init(remoteName: "origin", name: "main")
    ])
    let model = RemoteListViewModel(manager: manager,
                                    brancher: brancher,
                                    publisher: publisher)

    try #require(model.remotes.count == 1)
    #expect(model.remotes[0].branches.count == 1)
    let update = Task { @MainActor in
      try await waitForRemotesUpdate(in: model) {
        $0.count == 1 && $0[0].branches.count == 2
      }
    }

    brancher.remoteBranchArray = [
      .init(remoteName: "origin", name: "main"),
      .init(remoteName: "origin", name: "feature"),
    ]
    publisher.refsSubject.send()

    let remotes = try await update.value

    #expect(remotes[0].branches.count == 2)
    #expect(remotes[0].branches.compactMap { $0.item?.name }.sorted()
              == ["origin/feature", "origin/main"])
  }

  @Test
  @MainActor
  func configPublisherRefreshesRemoteList() async throws
  {
    let publisher = TestRepositoryPublisher()
    let manager = TestRemoteManager(remoteNames: ["origin"])
    let brancher = TestBrancher(remoteBranches: [
      .init(remoteName: "origin", name: "main")
    ])
    let model = RemoteListViewModel(manager: manager,
                                    brancher: brancher,
                                    publisher: publisher)

    try #require(model.remotes.map(\.name) == ["origin"])
    let update = Task { @MainActor in
      try await waitForRemotesUpdate(in: model) {
        $0.map(\.name) == ["origin", "upstream"]
      }
    }

    manager.remoteNameList = ["origin", "upstream"]
    brancher.remoteBranchArray = [
      .init(remoteName: "origin", name: "main"),
      .init(remoteName: "upstream", name: "develop"),
    ]
    publisher.configSubject.send()

    let remotes = try await update.value

    #expect(remotes.map(\.name) == ["origin", "upstream"])
    #expect(remotes[1].branches.compactMap { $0.item?.name }.sorted()
              == ["upstream/develop"])
  }

  /// Waits for the next published `remotes` value that matches `predicate`.
  ///
  /// The helper listens to the model's `@Published` stream directly so these
  /// tests block on the actual refresh signal instead of polling the main queue.
  @MainActor
  func waitForRemotesUpdate<Manager: RemoteManagement, Brancher: Branching>(
      in model: RemoteListViewModel<Manager, Brancher>,
      timeout: Duration = .seconds(1),
      matching predicate: @escaping @MainActor ([RemoteListViewModel<Manager, Brancher>.RemoteItem]) -> Bool)
    async throws -> [RemoteListViewModel<Manager, Brancher>.RemoteItem]
  {
    try await withThrowingTaskGroup(
        of: [RemoteListViewModel<Manager, Brancher>.RemoteItem].self) {
      group in
      group.addTask { @MainActor in
        for await remotes in model.$remotes.values {
          if predicate(remotes) {
            return remotes
          }
        }
        throw WaitError.remotesStreamEnded
      }
      group.addTask {
        try await Task.sleep(for: timeout)
        throw WaitError.timedOut
      }

      let remotes = try await group.next()
      group.cancelAll()
      return try #require(remotes)
    }
  }
}
