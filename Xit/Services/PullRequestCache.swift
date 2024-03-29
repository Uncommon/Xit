import Foundation

/// Object that will be notified of pull request changes.
protocol PullRequestClient: AnyObject
{
  func pullRequestUpdated(branch: String, requests: [PullRequest])
}

final class PullRequestCache
{
  // This can't be made generic because `protocol X : AnyObject` isn't enough
  // to convince the compiler that all instances will be class objects.
  class WeakClientRef
  {
    private(set) weak var client: (any PullRequestClient)?
    
    init(client: any PullRequestClient)
    {
      self.client = client
    }
  }
  
  private var clients = [WeakClientRef]()
  private weak var repository: (any RemoteManagement)?
  
  var requests: [any PullRequest] = []
  
  init(repository: any RemoteManagement)
  {
    self.repository = repository
  }
  
  func add(client: any PullRequestClient)
  {
    if !clients.contains(where: { $0.client === client }) {
      clients.append(WeakClientRef(client: client))
    }
  }
  
  func remove(client: any PullRequestClient)
  {
    clients.firstIndex { $0.client === client }
           .map { _ = clients.remove(at: $0) }
  }
  
  func refresh()
  {
    let remotes = repository?.remotes() ?? []

    requests.removeAll()
    guard !remotes.isEmpty
    else { return }

    Task.detached {
      Signpost.intervalStart(.refreshPullRequests)
      defer {
        Signpost.intervalEnd(.refreshPullRequests)
      }

      for remote in remotes {
        guard let service = Services.xit.pullRequestService(for: remote)
        else { continue }

        let requests = await service.getPullRequests()
        var branchMap: [String: [any PullRequest]] = [:]

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
    guard var request = requests.first(where: { $0.id == pullRequestID }),
          let service = Services.xit.pullRequestService(forID: request.serviceID)
    else { return }
    let userID = service.userID
    
    request.setReviewerStatus(userID: userID, status: approval)
    
    notifyChange(request: request)
  }
  
  private func notifyChange(request: any PullRequest)
  {
    forEachClient {
      (client) in
      client.pullRequestUpdated(branch: request.sourceBranch,
                                requests: [request])
    }
  }
  
  private func forEachClient(_ action: (any PullRequestClient) -> Void)
  {
    clients.compactMap { $0.client }.forEach(action)
  }
}
