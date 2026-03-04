import Foundation
import XitGit

/// URLSession-based Bitbucket Server service (parallel to Siesta-backed BitbucketServerAPI).
/// Provides async endpoints for pull request workflows.
final class BitbucketService: BaseHTTPService
{
  static let rootPath = "/rest/api/1.0"
  
  var userID: String { user?.slug ?? account.user }
  
  private let decoder = JSONDecoder()
  private(set) var user: User?
  
  // MARK: - Init
  init?(account: Account,
        password: String,
        passwordStorage: any PasswordStorage = KeychainStorage.shared,
        networkService: NetworkService? = nil)
  {
    var account = account
    
    account.location = account.location.appending(path: Self.rootPath)
    super.init(account: account,
               password: password,
               passwordStorage: passwordStorage,
               authenticationPath: "users/\(account.user)",
               networkService: networkService)
  }
  
  // MARK: - Auth hook
  override func didAuthenticate(data: Data) async
  {
    do {
      user = try decoder.decode(User.self, from: data)
    }
    catch {
      authenticationStatus = .failed(error)
    }
  }
  
  // MARK: - Helpers
  private func handleRequestError(_ error: Error)
  {
    if case NetworkError.unauthorized = error {
      authenticationStatus = .failed(error)
    }
  }
  
  private func pullRequestPath(_ request: BitbucketPR) -> String
  {
    let projectKey = request.request.toRef.repository.project.key
    let repoSlug = request.request.toRef.repository.slug
    let requestID = request.request.id
    
    return "projects/\(projectKey)/repos/\(repoSlug)/pull-requests/\(requestID)/"
  }
  
  private func performRequest(_ endpoint: Endpoint) async throws
  {
    do {
      _ = try await networkService.request(endpoint) as Data
    }
    catch {
      handleRequestError(error)
      throw error
    }
  }
  
  private func update(request: BitbucketPR,
                      approved: Bool,
                      status: ReviewerStatus) async throws
  {
    guard let userSlug = user?.slug
    else { throw BitbucketError.missingUser }
    let path = pullRequestPath(request) + "participants/\(userSlug)"
    let payload: [String: Any] = [
      "user": ["slug": userSlug],
      "approved": approved,
      "status": status.rawValue,
    ]
    let body = try JSONSerialization.data(withJSONObject: payload, options: [])
    let endpoint = Endpoint(baseURL: account.location,
                            path: path,
                            method: .put,
                            headers: ["Content-Type": "application/json"],
                            body: body)
    
    try await performRequest(endpoint)
  }
  
  // MARK: - Types
  enum BitbucketError: Error
  {
    case missingUser
    case invalidPullRequest
  }
  
  struct PagedResponse<T>: Codable, Sendable where T: Codable & Sendable
  {
    let size, limit: Int
    let start: Int? // Not present for the first page
    let isLastPage: Bool
    let values: [T]
  }

  enum PullRequestState: String, Codable
  {
    case open = "OPEN"
    case declined = "DECLINED"
    case merged = "MERGED"
    case all = "ALL" // queries only
  }

  enum ReviewerRole: String, Codable, Sendable
  {
    case author = "AUTHOR"
    case reviewer = "REVIEWER"
    case participant = "PARTICIPANT"
  }

  enum ReviewerStatus: String, Codable, Sendable
  {
    case approved = "APPROVED"
    case unapproved = "UNAPPROVED"
    case needsWork = "NEEDS_WORK"
    
    var approval: PullRequestApproval
    {
      switch self {
        case .approved:   return .approved
        case .unapproved: return .unreviewed
        case .needsWork:  return .needsWork
      }
    }
    
    init(approval: PullRequestApproval)
    {
      switch approval {
        case .approved:   self = .approved
        case .unreviewed: self = .unapproved
        case .needsWork:  self = .needsWork
        case .unknown:    self = .unapproved
      }
    }
  }

  struct Project: Codable, Sendable
  {
    let key: String
    let id: Int?
    let links: Links?
    let name: String?
    let `public`: Bool?
    let type: String? // NORMAL and what else?
  }

  struct Repository: Codable, Sendable
  {
    let slug: String
    let name: String?
    let project: Project
    let links: Links?
    let forkable: Bool?
    let id: Int?
    let `public`: Bool?
    let scmId: String?
    let statusMessage: String?
  }

  struct Ref: Codable, Sendable
  {
    let id: String
    let displayId: String?
    let latestCommit: String? // SHA
    let repository: Repository
  }

  struct User: Codable, Equatable, Sendable
  {
    let name: String
    let emailAddress: String?
    let id: Int
    let displayName: String
    let active: Bool
    let slug: String
    let type: UserType
    let links: Links?
  }
  
  enum UserType: String, Codable, Sendable
  {
    case normal = "NORMAL"
    case service = "SERVICE"
  }
  
  struct Link: Codable, Equatable, Sendable
  {
    let href: String?
    let name: String?
  }
  
  struct Links: Codable, Equatable, Sendable
  {
    let `self`: [Link]
    let clone: [Link]?
  }

  struct Participant: Codable, Sendable
  {
    let user: User
    let role: ReviewerRole
    var approved: Bool
    var status: ReviewerStatus
    let lastReviewedCommit: String?
  }

  struct PullRequest: Codable, Sendable
  {
    let id: Int
    let version: Int
    let title: String
    let description: String?
    var state: PullRequestState
    let open: Bool
    let closed: Bool
    let closedDate: Int?
    let createdDate, updatedDate: Int // convert to date
    let fromRef, toRef: Ref
    let locked: Bool
    let author: Participant
    var reviewers: [Participant]
    let participants: [Participant]?
    let links: Links
  }

  struct BitbucketPR: Xit.PullRequest
  {
    var request: BitbucketService.PullRequest
    let serviceID: UUID
    let userID: Int?
    
    init(request: BitbucketService.PullRequest, service: BitbucketService)
    {
      self.request = request
      self.serviceID = service.id
      self.userID = service.user?.id
    }
    
    var sourceBranch: String { request.fromRef.id }
    var sourceRepo: URL?
    {
      let protocols = ["https", "ssh"]
      
      for proto in protocols {
        if let link = request.fromRef.repository.links?.clone?.first(where: { $0.name == proto }),
           let href = link.href {
          return URL(string: href)
        }
      }
      return nil
    }
    var displayName: String { request.title }
    var id: String { String(request.id) }
    var authorName: String? { request.author.user.displayName }
    var status: PullRequestStatus
    {
      get {
        switch request.state {
          case .open: .open
          case .declined: .inactive
          case .merged: .merged
          default: .other
        }
      }
      set {
        switch newValue {
          case .open: request.state = .open
          case .inactive: request.state = .declined
          case .merged: request.state = .merged
          default: break
        }
      }
    }
    var webURL: URL?
    {
      guard let href = request.links.`self`.first?.href
      else { return nil }
      
      return URL(string: href)
    }
    var availableActions: PullRequestActions
    {
      switch request.state {
        case .declined, .merged:
          return []
        case .open:
          guard let userID = self.userID
          else { return [] }
          
          if request.author.user.id == userID {
            return [.decline]
          }
          if let reviewer = request.reviewers.first(where: { $0.user.id == userID }) {
            return reviewer.approved ? [.unapprove, .needsWork] : [.approve, .needsWork]
          }
          return []
        default:
          return []
      }
    }
    
    func matchRemote(url: URL) -> Bool
    {
      guard let scheme = url.scheme
      else { return false }
      let link = request.fromRef.repository.links?.clone?.first { $0.href?.hasPrefix(scheme) ?? false }
      
      return link?.href == url.absoluteString
    }
    
    func reviewerStatus(userID: String) -> PullRequestApproval
    {
      let reviewer = request.reviewers.first { $0.user.slug == userID }
      
      return reviewer?.status.approval ?? .unreviewed
    }
    
    mutating func setReviewerStatus(userID: String, status: PullRequestApproval)
    {
      guard let index = request.reviewers.firstIndex(where: { $0.user.slug == userID })
      else { return }
      
      request.reviewers[index].approved = status == .approved
      request.reviewers[index].status = ReviewerStatus(approval: status)
    }
  }
}

extension BitbucketService: ServiceAPI
{
  var type: AccountType { .bitbucketServer }
}

extension BitbucketService: RemoteService
{
  func match(remote: any Remote) -> Bool
  {
    remote.url?.host == account.location.host
  }
}

extension BitbucketService: PullRequestService
{
  func getPullRequests() async -> [any Xit.PullRequest]
  {
    var results: [BitbucketPR] = []
    var nextStart: Int?
    
    repeat {
      let queryItems = nextStart.map { [URLQueryItem(name: "start", value: String($0))] }
      let endpoint = Endpoint(baseURL: account.location,
                              path: "dashboard/pull-requests",
                              method: .get,
                              queryItems: queryItems)
      
      do {
        let page: PagedResponse<PullRequest> = try await networkService.request(endpoint)
        results.append(contentsOf: page.values.map { BitbucketPR(request: $0, service: self) })
        if page.isLastPage {
          nextStart = nil
        }
        else {
          let currentStart = page.start ?? nextStart ?? 0
          nextStart = currentStart + page.values.count
        }
      }
      catch {
        handleRequestError(error)
        return results
      }
    } while nextStart != nil
    
    return results.map { $0 as any Xit.PullRequest }
  }
  
  func approve(request: any Xit.PullRequest) async throws
  {
    guard let pr = request as? BitbucketPR
    else { throw BitbucketError.invalidPullRequest }
    
    try await update(request: pr, approved: true, status: .approved)
  }
  
  func unapprove(request: any Xit.PullRequest) async throws
  {
    guard let pr = request as? BitbucketPR
    else { throw BitbucketError.invalidPullRequest }
    
    try await update(request: pr, approved: false, status: .unapproved)
  }
  
  func needsWork(request: any Xit.PullRequest) async throws
  {
    guard let pr = request as? BitbucketPR
    else { throw BitbucketError.invalidPullRequest }
    
    try await update(request: pr, approved: false, status: .needsWork)
  }
  
  func merge(request: any Xit.PullRequest) async throws
  {
    guard let pr = request as? BitbucketPR
    else { throw BitbucketError.invalidPullRequest }
    let endpoint = Endpoint(baseURL: account.location,
                            path: pullRequestPath(pr) + "merge",
                            method: .post)
    
    try await performRequest(endpoint)
  }
}
