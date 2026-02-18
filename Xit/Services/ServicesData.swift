import Foundation
import Siesta
import XitGit

protocol PullRequest: Sendable // Identifiable
{
  /// In order to be `Sendable`, the source service is identified by ID rather
  /// than direct reference.
  var serviceID: UUID { get }
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
  {
    guard let service = Services.xit.pullRequestService(forID: serviceID)
    else { return .unknown }
    return reviewerStatus(userID: service.userID)
  }
  
  func matchRemote(url: URL) -> Bool
  {
    return sourceRepo == url
  }
}

enum PullRequestStatus: String
{
  case open
  case inactive
  case merged
  case other
}

enum PullRequestApproval: String
{
  case approved
  case needsWork
  case unreviewed
  case unknown
}

/// A service that is related to specific remote repositories
protocol RemoteService
{
  /// True if the remote URL would be hosted on this service
  func match(remote: any Remote) -> Bool
}

/// A service with an identifier for the logged-in user
protocol UserIDService
{
  var userID: String { get }
}

/// A service that manages pull requests
protocol PullRequestService: RemoteService, UserIDService
{
  func getPullRequests() async -> [any Xit.PullRequest]
  func approve(request: any PullRequest) async throws
  func unapprove(request: any PullRequest) async throws
  func needsWork(request: any PullRequest) async throws
  func merge(request: any PullRequest) async throws
}

/// The pull request actions that a particular service implements.
struct PullRequestActions: OptionSet, Sendable
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
