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
}
