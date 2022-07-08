// URL and UUID should be Sendable
@preconcurrency import Foundation
import Siesta

/// Used for testing pull request status
struct FakePullRequest: PullRequest
{
  let serviceID: UUID = .init()
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

final class FakePRService: Service, PullRequestService, AccountService
{
  required init?(account: Account, password: String)
  {
    assertionFailure("oops")
    return nil
  }

  init()
  {
    super.init()
  }

  func accountUpdated(oldAccount: Account, newAccount: Account) {}
  
  func getPullRequests(callback: @escaping ([any PullRequest]) -> Void)
  {
    let branches = ["master", "delete", "merge"]
    let statuses: [PullRequestStatus] = [.open, .inactive, .merged]
    
    let requests = zip(branches, statuses).map {
      FakePullRequest(sourceBranch: "refs/heads/" + $0, status: $1)
    }
    
    callback(requests)
  }

  func getPullRequests() async -> [any PullRequest]
  {
    let branches = ["master", "delete", "merge"]
    let statuses: [PullRequestStatus] = [.open, .inactive, .merged]

    let requests = zip(branches, statuses).map {
      FakePullRequest(sourceBranch: "refs/heads/" + $0, status: $1)
    }

    return requests
  }
  
  func approve(request: any PullRequest) {}

  func unapprove(request: any PullRequest) {}

  func needsWork(request: any PullRequest) {}
  
  func merge(request: any PullRequest) {}
  
  func match(remote: any Remote) -> Bool
  { true }
  
  var userID: String { "You" }
}
