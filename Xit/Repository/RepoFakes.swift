#if DEBUG

class FakeBrancher: EmptyBranching
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

class FakeRemoteManager: EmptyRemoteManagement
{
  typealias LocalBranch = FakeLocalBranch
  typealias Remote = FakeRemote
  
  var remoteNames: [String]
  
  init(remoteNames: [String])
  {
    self.remoteNames = remoteNames
  }
}

#endif
