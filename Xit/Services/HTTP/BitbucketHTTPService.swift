import Foundation

/// URLSession-based Bitbucket Server service (parallel to Siesta-backed BitbucketServerAPI).
/// Provides async endpoints for pull request workflows.
final class BitbucketHTTPService: BaseHTTPService
{
  static let rootPath = "/rest/api/1.0"
  
  var userID: String { user?.slug ?? account.user }
  
  private let decoder = JSONDecoder()
  private(set) var user: BitbucketServer.User?
  
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
      user = try decoder.decode(BitbucketServer.User.self, from: data)
    }
    catch {
      authenticationStatus = .failed(error)
    }
  }
  
  // MARK: - Helpers
  private func pullRequestPath(_ request: BitbucketPR) -> String
  {
    let projectKey = request.request.toRef.repository.project.key
    let repoSlug = request.request.toRef.repository.slug
    let requestID = request.request.id
    
    return "projects/\(projectKey)/repos/\(repoSlug)/pull-requests/\(requestID)/"
  }
  
  private func update(request: BitbucketPR,
                      approved: Bool,
                      status: BitbucketServer.ReviewerStatus) async throws
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
    
    _ = try await networkService.request(endpoint) as Data
  }
  
  // MARK: - Types
  enum BitbucketError: Error
  {
    case missingUser
    case invalidPullRequest
  }
  
  struct BitbucketPR: Xit.PullRequest
  {
    var request: BitbucketServer.PullRequest
    let serviceID: UUID
    let userID: Int?
    
    init(request: BitbucketServer.PullRequest, service: BitbucketHTTPService)
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
      request.reviewers[index].status = BitbucketServer.ReviewerStatus(approval: status)
    }
  }
}

extension BitbucketHTTPService: ServiceAPI
{
  var type: AccountType { .bitbucketServer }
}

extension BitbucketHTTPService: RemoteService
{
  func match(remote: any Remote) -> Bool
  {
    remote.url?.host == account.location.host
  }
}

extension BitbucketHTTPService: PullRequestService
{
  func getPullRequests() async -> [any PullRequest]
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
        let page: BitbucketServer.PagedPullRequest = try await networkService.request(endpoint)
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
        return results
      }
    } while nextStart != nil
    
    return results.map { $0 as any PullRequest }
  }
  
  func approve(request: any PullRequest) async throws
  {
    guard let pr = request as? BitbucketPR
    else { throw BitbucketError.invalidPullRequest }
    
    try await update(request: pr, approved: true, status: .approved)
  }
  
  func unapprove(request: any PullRequest) async throws
  {
    guard let pr = request as? BitbucketPR
    else { throw BitbucketError.invalidPullRequest }
    
    try await update(request: pr, approved: false, status: .unapproved)
  }
  
  func needsWork(request: any PullRequest) async throws
  {
    guard let pr = request as? BitbucketPR
    else { throw BitbucketError.invalidPullRequest }
    
    try await update(request: pr, approved: false, status: .needsWork)
  }
  
  func merge(request: any PullRequest) async throws
  {
    guard let pr = request as? BitbucketPR
    else { throw BitbucketError.invalidPullRequest }
    let endpoint = Endpoint(baseURL: account.location,
                            path: pullRequestPath(pr) + "merge",
                            method: .post)
    
    _ = try await networkService.request(endpoint) as Data
  }
}
