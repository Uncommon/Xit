import Foundation

protocol PullRequest
{
  var service: PullRequestService { get }
  var sourceBranch: String { get }
  var sourceRepo: URL? { get }
  var displayName: String { get }
  var id: String { get }
  var authorName: String? { get }
  var status: PullRequestStatus { get }
  var webURL: URL? { get }
  var availableActions: PullRequestActions { get }

  func matchRemote(url: URL) -> Bool
  func isApproved(by userID: String) -> Bool
}

extension PullRequest
{
  func matchRemote(url: URL) -> Bool
  {
    return sourceRepo == url
  }
}

enum PullRequestStatus
{
  case open
  case inactive
  case merged
  case other
}

protocol RemoteService
{
  /// True if the remote URL would be hosted on this service
  func match(remote: Remote) -> Bool
}

protocol PullRequestService: RemoteService
{
  func getPullRequests(callback: @escaping ([Xit.PullRequest]) -> Void)
  
  func approve(request: PullRequest)
  func unapprove(request: PullRequest)
  func needsWork(request: PullRequest)
  func merge(request: PullRequest)
}

/// The pull request actions that a particular service implements.
struct PullRequestActions: OptionSet
{
  let rawValue: UInt32
  
  static let approve   = PullRequestActions(rawValue: 1 << 0)
  static let unapprove = PullRequestActions(rawValue: 1 << 1)
  static let merge     = PullRequestActions(rawValue: 1 << 2)
  static let decline   = PullRequestActions(rawValue: 1 << 3) // or "cancel"
  static let needsWork = PullRequestActions(rawValue: 1 << 4)
  
  // Reopen and delete would require keeping track of inactive (declined/canceled)
  // reviews, and that probably isn't desirable.
}
