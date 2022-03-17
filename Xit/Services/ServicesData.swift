import Foundation
import Siesta

protocol PullRequest
{
  var service: PullRequestService { get }
  var sourceBranch: String { get }
  var sourceRepo: URL? { get }
  var displayName: String { get }
  var id: String { get }
  var authorName: String? { get }
  var status: PullRequestStatus { get set }
  var userApproval: PullRequestApproval { get }
  var webURL: URL? { get }
  var availableActions: PullRequestActions { get }

  func matchRemote(url: URL) -> Bool
  func reviewerStatus(userID: String) -> PullRequestApproval
  mutating func setReviewerStatus(userID: String, status: PullRequestApproval)
}

extension PullRequest
{
  var userApproval: PullRequestApproval
  { reviewerStatus(userID: service.userID) }
  
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

enum PullRequestApproval
{
  case approved
  case needsWork
  case unreviewed
}

/// A service that is related to specific remote repositories
protocol RemoteService
{
  /// True if the remote URL would be hosted on this service
  func match(remote: Remote) -> Bool
}

/// A service with an identifier for the logged-in user
protocol UserIDService
{
  var userID: String { get }
}

/// A service that manages pull requests
protocol PullRequestService: RemoteService, UserIDService
{
  func getPullRequests() async -> [Xit.PullRequest]
  func approve(request: PullRequest) async throws
  func unapprove(request: PullRequest) async throws
  func needsWork(request: PullRequest) async throws
  func merge(request: PullRequest) async throws
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
