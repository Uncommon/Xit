import Foundation
import Siesta

/// Used for testing pull request status
struct FakePullRequest: PullRequest
{
  let service: PullRequestService
  var sourceBranch: String
  var sourceRepo: URL? { nil }
  var displayName: String { "fake" }
  var id: String { "0" }
  let authorName: String? = nil
  var status: PullRequestStatus
  let webURL: URL? = nil
  let availableActions: PullRequestActions = []
  
  func reviewerStatus(userID: String) -> PullRequestApproval { .unreviewed }
  
  func matchRemote(url: URL) -> Bool { true }

  mutating func setReviewerStatus(userID: String, status: PullRequestApproval)
  {
  }
}

class FakePRService: Service, PullRequestService, AccountService
{
  init()
  {
    super.init()
  }
  
  func accountUpdated(oldAccount: Account, newAccount: Account) {}
  
  func getPullRequests(callback: @escaping ([PullRequest]) -> Void)
  {
    let branches = ["master", "delete", "merge"]
    let statuses: [PullRequestStatus] = [.open, .inactive, .merged]
    
    let requests = zip(branches, statuses).map {
      FakePullRequest(service: self, sourceBranch: "refs/heads/" + $0, status: $1)
    }
    
    callback(requests)
  }
  
  func approve(request: PullRequest,
               onSuccess: @escaping () -> Void,
               onFailure: @escaping (RequestError) -> Void)
  { onSuccess() }

  func unapprove(request: PullRequest,
                 onSuccess: @escaping () -> Void,
                 onFailure: @escaping (RequestError) -> Void)
  { onSuccess() }

  func needsWork(request: PullRequest,
                 onSuccess: @escaping () -> Void,
                 onFailure: @escaping (RequestError) -> Void)
  { onSuccess() }
  
  func merge(request: PullRequest) {}
  
  func match(remote: Remote) -> Bool
  { true }
  
  var userID: String { "You" }
}
