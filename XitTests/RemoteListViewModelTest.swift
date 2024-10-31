import Testing
@testable import Xit

struct RemoteListViewModelTest
{
  @Test
  func singleRemote() throws
  {
    let remoteName = "origin"
    let manager = FakeRemoteManager(remoteNames: [remoteName])
    let brancher = FakeBrancher(remoteBranches: [
      .init(remoteName: remoteName, name: "main")
    ])
    let model = RemoteListViewModel(manager: manager, brancher: brancher)
    
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
    let manager = FakeRemoteManager(remoteNames: remoteNames)
    let brancher = FakeBrancher(remoteBranches: branches1.map {
      .init(remoteName: remoteNames[0], name: $0)
    } + branches2.map {
      .init(remoteName: remoteNames[1], name: $0)
    })
    let model = RemoteListViewModel(manager: manager, brancher: brancher)
    
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
    let manager = FakeRemoteManager(remoteNames: [remoteName])
    let brancher = FakeBrancher(remoteBranches: [
      .init(remoteName: remoteName, name: "main"),
      .init(remoteName: remoteName, name: "superBranch"),
      .init(remoteName: remoteName, name: "superBranch/subBranch"),
    ])
    let model = RemoteListViewModel(manager: manager, brancher: brancher)

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
    let manager = FakeRemoteManager(remoteNames: remoteNames)
    let brancher = FakeBrancher(remoteBranches: branches1.map {
      .init(remoteName: remoteNames[0], name: $0)
    } + branches2.map {
      .init(remoteName: remoteNames[1], name: $0)
    })
    let model = RemoteListViewModel(manager: manager, brancher: brancher)

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
    let manager = FakeRemoteManager(remoteNames: remoteNames)
    let brancher = FakeBrancher(remoteBranches: branches1.map {
      .init(remoteName: remoteNames[0], name: $0)
    } + branches2.map {
      .init(remoteName: remoteNames[1], name: $0)
    })
    let model = RemoteListViewModel(manager: manager, brancher: brancher)

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
}
