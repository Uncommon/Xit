import Foundation

/// Object that will be notified of pull request changes.
protocol PullRequestClient: AnyObject
{
  func pullRequestUpdated(branch: String, requests: [PullRequest])
}

class PullRequestCache
{
  // This can't be made generic because `protocol X : AnyObject` isn't enough
  // to convince the compiler that all instances will be class objects.
  class WeakClientRef
  {
    private(set) weak var client: PullRequestClient?
    
    init(client: PullRequestClient)
    {
      self.client = client
    }
  }
  
  private var clients = [WeakClientRef]()
  private let repository: RemoteManagement
  
  internal(set) var requests: [PullRequest] = []
  
  init(repository: RemoteManagement)
  {
    self.repository = repository
  }
  
  func add(client: PullRequestClient)
  {
    if !clients.contains(where: { $0.client === client }) {
      clients.append(WeakClientRef(client: client))
    }
  }
  
  func remove(client: PullRequestClient)
  {
    clients.index(where: { $0.client === client })
           .map { _ = clients.remove(at: $0) }
  }
  
  func refresh()
  {
    let remotes = repository.remotes()

    requests.removeAll()
    
    for remote in remotes {
      guard let service = Services.shared.pullRequestService(remote: remote)
      else { continue }
      
      service.getPullRequests {
        (requests) in
        var branchMap: [String: [PullRequest]] = [:]
        
        self.requests.append(contentsOf: requests)
        
        for request in requests {
          if let branchRequests = branchMap[request.sourceBranch] {
            branchMap[request.sourceBranch] = branchRequests + [request]
          }
          else {
            branchMap[request.sourceBranch] = [request]
          }
        }
        for clientWrapper in self.clients {
          for (branch, requests) in branchMap {
            clientWrapper.client?.pullRequestUpdated(branch: branch,
                                                     requests: requests)
          }
        }
      }
    }
  }
}
