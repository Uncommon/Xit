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
  
  var requests: [PullRequest] = []
  
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
    clients.firstIndex { $0.client === client }
           .map { _ = clients.remove(at: $0) }
  }
  
  func refresh()
  {
    let remotes = repository.remotes()

    requests.removeAll()
    
    Signpost.intervalStart(.refreshPullRequests)
    defer {
      Signpost.intervalEnd(.refreshPullRequests)
    }
    
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
        self.forEachClient {
          (client) in
          for (branch, requests) in branchMap {
            client.pullRequestUpdated(branch: branch, requests: requests)
          }
        }
      }
    }
  }
  
  func update(pullRequestID: String, status: PullRequestStatus)
  {
    if let requestIndex = requests.firstIndex(where: { $0.id == pullRequestID }) {
      requests[requestIndex].status = status
      
      let request = requests[requestIndex]
      
      notifyChange(request: request)
    }
  }
  
  func update(pullRequestID: String, approval: PullRequestApproval)
  {
    guard let requestIndex = requests.firstIndex(where: { $0.id == pullRequestID })
    else { return }
    let userID = requests[requestIndex].service.userID
    
    requests[requestIndex].setReviewerStatus(userID: userID, status: approval)
    
    let request = requests[requestIndex]

    notifyChange(request: request)
  }
  
  private func notifyChange(request: PullRequest)
  {
    forEachClient {
      (client) in
      client.pullRequestUpdated(branch: request.sourceBranch,
                                requests: [request])
    }
  }
  
  private func forEachClient(_ action: (PullRequestClient) -> Void)
  {
    for clientWrapper in clients {
      if let client = clientWrapper.client {
        action(client)
      }
    }
  }
}
