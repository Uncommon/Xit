import Foundation
@preconcurrency import Siesta

enum BitbucketServer
{
  struct PagedResponse<T>: Codable where T: Codable
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

  enum UserType: String, Codable
  {
    case normal = "NORMAL"
    case service = "SERVICE"
  }
  
  enum ReviewerRole: String, Codable
  {
    case author = "AUTHOR"
    case reviewer = "REVIEWER"
    case participant = "PARTICIPANT"
  }
  
  enum ReviewerStatus: String, Codable
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

  struct Project: Codable
  {
    let key: String
    let id: Int?
    let links: Links?
    let name: String?
    let `public`: Bool?
    let type: String? // NORMAL and what else?
  }

  struct Repository: Codable
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

  struct Ref: Codable
  {
    let id: String
    let displayId: String?
    let latestCommit: String? // SHA
    let repository: Repository
  }

  struct User: Codable, Equatable
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
  
  struct Link: Codable, Equatable
  {
    let href: String?
    let name: String?
  }
  
  struct Links: Codable, Equatable
  {
    let `self`: [Link]
    let clone: [Link]?
  }
  
  struct Participant: Codable
  {
    let user: User
    let role: ReviewerRole
    var approved: Bool
    var status: ReviewerStatus
    let lastReviewedCommit: String?
  }

  struct PullRequest: Codable
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
  
  typealias PagedPullRequest = PagedResponse<PullRequest>
}

final class BitbucketServerAPI: BasicAuthService, ServiceAPI
{
  var type: AccountType { .bitbucketServer }
  var user: BitbucketServer.User?
  static let rootPath = "/rest/api/1.0"
  
  struct PullRequest: Xit.PullRequest
  {
    var request: BitbucketServer.PullRequest
    let serviceID: UUID

    // Stored for convenience
    let userID: Int?
    
    var sourceBranch: String { request.fromRef.id }
    var sourceRepo: URL?
    {
      let protocols = ["https", "ssh"]
      
      for proto in protocols {
        if let link = request.fromRef.repository
                             .links?.clone?.first(where: { $0.name == proto }),
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
          case .open:
            return .open
          case .declined:
            return .inactive
          case .merged:
            return .merged
          default:
            return .other
        }
      }
      set {
        switch newValue {
          case .open:
            request.state = .open
          case .inactive:
            request.state = .declined
          case .merged:
            request.state = .merged
          default:
            break
        }
      }
    }
    var webURL: URL?
    {
      guard let link = request.links.`self`.first,
            let href = link.href
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
          if let reviewer = request.reviewers
                            .first(where: { $0.user.id == userID }) {
            return reviewer.approved ? [.unapprove, .needsWork]
                                     : [.approve, .needsWork]
          }
          // who can merge?
          return []
        default:
          return []
      }
    }

    init(request: BitbucketServer.PullRequest, service: BitbucketServerAPI) {
      self.request = request
      self.serviceID = service.id
      self.userID = service.user?.id
    }
    
    func matchRemote(url: URL) -> Bool
    {
      guard let scheme = url.scheme
      else { return false }
      let link = request.fromRef.repository
        .links?.clone?.first { $0.href?.hasPrefix(scheme) ?? false }
      
      return link?.href == url.absoluteString
    }
    
    func reviewerStatus(userID: String) -> PullRequestApproval
    {
      let reviewer = request.reviewers
                            .first { $0.user.slug == userID }
      
      return reviewer?.status.approval ?? .unreviewed
    }
    
    mutating func setReviewerStatus(userID: String, status: PullRequestApproval)
    {
      guard let index = request.reviewers
                               .firstIndex(where: { $0.user.slug == userID })
      else { return }
      
      request.reviewers[index].approved = status == .approved
      request.reviewers[index].status =
          BitbucketServer.ReviewerStatus(approval: status)
    }
  }
  
  static func transformer<T>(entity: Entity<Data>) throws -> T where T: Decodable
  {
    do {
      return try JSONDecoder().decode(T.self, from: entity.content)
    }
    catch let error as DecodingError {
      print(error.context.debugDescription)
      throw error
    }
  }
  
  init?(account: Account, password: String)
  {
    guard var fullBaseURL = URLComponents(url: account.location,
                                          resolvingAgainstBaseURL: false)
    else { return nil }
    
    fullBaseURL.path = BitbucketServerAPI.rootPath
    
    guard let location = fullBaseURL.url
    else { return nil }
    
    account.location = location
    
    super.init(account: account, password: password,
               authenticationPath: "users/\(account.user)")
    
    let userTransformer: (Entity<Data>) throws -> BitbucketServer.User =
          BitbucketServerAPI.transformer
    let prTransformer: (Entity<Data>) throws -> BitbucketServer.PagedPullRequest =
          BitbucketServerAPI.transformer

    configureTransformer("/users/*", contentTransform: userTransformer)
    configureTransformer("/dashboard/pull-requests",
                         contentTransform: prTransformer)
  }
  
  override func didAuthenticate(responseResource: Resource)
  {
    Task.detached {
      let content = try await responseResource.data.content
      guard let user = content as? BitbucketServer.User
      else {
        self.authenticationStatus = .failed(nil)
        return
      }
      self.user = user
    }
  }

  @MainActor
  func pullRequests() -> Resource
  {
    let url = URL(string: "dashboard/pull-requests", relativeTo: baseURL)
    
    return self.resource(absoluteURL: url)
  }
  
  func setStatus(pullRequestID id: Int, projectKey key: String,
                 repoSlug slug: String,
                 status: BitbucketServer.ReviewerStatus) -> Request
  {
    let href = """
          projects/\(key)/repos/\(slug)/pull-requests/\(id)\
          /participants/\(user!.slug)
          """
    let resource = self.resource(absoluteURL: URL(string: href,
                                                  relativeTo: baseURL))
    
    let data = ["user": ["name": user!.slug],
                "approved": status == .approved,
                "status": status.rawValue,
                ] as [String: Any]
    
    return resource.request(.put, json: data)
  }
}

extension BitbucketServerAPI: RemoteService
{
  func match(remote: any Remote) -> Bool
  {
    let host = remote.url?.host
    
    return host == baseURL?.host
  }
}

extension BitbucketServerAPI: PullRequestService
{
  var userID: String { user?.slug ?? "" }
  
  func getPullRequests() async -> [Xit.PullRequest]
  {
    do {
      let pullRequests = await pullRequests()
      let data = try await pullRequests.data
      guard let requests = data.content as? BitbucketServer.PagedPullRequest
      else {
        return []
      }

      let result = requests.values.map { PullRequest(request: $0,
                                                     service: self) }

      #if DEBUG
      for request in result {
        print("\(request.status): \(request.sourceBranch)")
      }
      #endif
      return result
    }
    catch {
      return []
    }
  }
  
  func pullRequestPath(_ request: PullRequest) -> String
  {
    let projectKey = request.request.toRef.repository.project.key
    let repoSlug = request.request.toRef.repository.slug
    let requestID = request.request.id
    
    return "projects/\(projectKey)/repos/\(repoSlug)/pull-requests/\(requestID)/"
  }
  
  func update(request: PullRequest,
              approved: Bool,
              status: BitbucketServer.ReviewerStatus) async throws
  {
    guard let userSlug = user?.slug
    else {
        // error
        return
    }

    let resource = self.resource(pullRequestPath(request) +
                                 "participants/\(userSlug)")
    let data: [String: Any] = ["user": ["slug": userSlug],
                               "approved": approved,
                               "status": status.rawValue]
    let request = resource.request(.put, json: data)

    try await request.complete()
  }

  func approve(request: Xit.PullRequest) async throws
  {
    if let request = request as? PullRequest {
      try await update(request: request, approved: true, status: .approved)
    }
  }

  func unapprove(request: Xit.PullRequest) async throws
  {
    if let request = request as? PullRequest {
      try await update(request: request, approved: false, status: .unapproved)
    }
  }

  func needsWork(request: Xit.PullRequest) async throws
  {
    if let request = request as? PullRequest {
      try await update(request: request, approved: false, status: .needsWork)
    }
  }

  func merge(request: Xit.PullRequest) async throws
  {
    guard let request = request as? PullRequest
    else { return }

    try await self.resource(pullRequestPath(request) + "merge")
                  .request(.post)
                  .complete()

    // anything else?
  }
}
