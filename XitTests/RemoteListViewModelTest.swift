import Testing
@testable import Xit

struct RemoteListViewModelTest
{
  class RemoteManager: EmptyRemoteManagement
  {
    typealias LocalBranch = FakeLocalBranch
    typealias Remote = FakeRemote
    
    var remoteNames: [String]
    
    init(remoteNames: [String])
    {
      self.remoteNames = remoteNames
    }
  }
  
  class Brancher: EmptyBranching
  {
    typealias LocalBranch = FakeLocalBranch
    typealias RemoteBranch = LocalBranch.RemoteBranch
    
    var remoteBranchArray: [RemoteBranch]
    var remoteBranches: AnySequence<RemoteBranch>
    { .init(remoteBranchArray) }
    
    init(remoteBranches: [LocalBranch.RemoteBranch])
    {
      self.remoteBranchArray = remoteBranches
    }
  }
  
  @Test
  func singleEmptyRemote() throws
  {
    let remoteName = "origin"
    let manager = RemoteManager(remoteNames: [remoteName])
    let brancher = Brancher(remoteBranches: [
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
    let manager = RemoteManager(remoteNames: remoteNames)
    let brancher = Brancher(remoteBranches: branches1.map {
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
}
