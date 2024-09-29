import Foundation
import Algorithms

class RemoteListViewModel<Manager: RemoteManagement, Brancher: Branching>
  : FilteringListViewModel
    where Manager.LocalBranch == Brancher.LocalBranch
{
  typealias Remote = Manager.Remote
  typealias RemoteBranch = Brancher.RemoteBranch
  
  let manager: Manager
  let brancher: Brancher
  
  struct RemoteItem
  {
    let name: String
    let branches: [PathTreeNode<RemoteBranch>]
  }
  
  var unfilteredRemotes: [RemoteItem] = []
  @Published var remotes: [RemoteItem] = []
  
  init(manager: Manager, brancher: Brancher)
  {
    self.manager = manager
    self.brancher = brancher
    super.init()
    
    updateList()
  }
  
  func updateList()
  {
    var branchesByRemote: [String: [RemoteBranch]] = [:]
    
    for branch in brancher.remoteBranches {
      if let remoteName = branch.remoteName {
        branchesByRemote[remoteName, default: []].append(branch)
      }
    }
    
    unfilteredRemotes = branchesByRemote.map {
      .init(name: $0.key,
            branches: PathTreeNode<RemoteBranch>.makeHierarchy(
              from: $0.value, prefix: "refs/remotes/\($0.key)/"))
    }
    filterChanged(filter)
  }
  
  override func filterChanged(_ newFilter: String)
  {
    remotes = unfilteredRemotes // TODO: actual filtering
  }
}
