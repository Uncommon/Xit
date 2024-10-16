import Foundation

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
  @Published var searchScope: RemoteSearchScope = .branches
  
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
    if newFilter.isEmpty {
      remotes = unfilteredRemotes
    }
    else {
      let lowerCased = LowerCaseString(newFilter)
      
      remotes = switch searchScope {
        case .branches:
          unfilteredRemotes.map {
            .init(name: $0.name,
                  branches: $0.branches.filtered(with: lowerCased))
          }
        case .remotes:
          unfilteredRemotes.filter {
            lowerCased.isSubString(of: $0.name)
          }
      }
    }
  }
}
