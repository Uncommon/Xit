import Foundation
import Siesta

enum BitbucketServer
{
  struct PagedResponse<T> : Codable where T: Codable
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
        case .needsWork: return .needsWork
      }
    }
    
    init(approval: PullRequestApproval)
    {
      switch approval {
        case .approved: self = .approved
        case .unreviewed: self = .unapproved
        case .needsWork: self = .needsWork
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
    let emailAddress: String
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

class BitbucketServerAPI: BasicAuthService, ServiceAPI
{
  var type: AccountType { return .bitbucketServer }
  var user: BitbucketServer.User?
  static let rootPath = "/rest/api/1.0"
  
  struct PullRequest: Xit.PullRequest
  {
    var request: BitbucketServer.PullRequest
    let bitbucketService: BitbucketServerAPI
    
    var service: PullRequestService { return bitbucketService }
    var sourceBranch: String { return request.fromRef.id }
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
    var displayName: String { return request.title }
    var id: String { return String(request.id) }
    var authorName: String? { return request.author.user.displayName }
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
          guard let userID = bitbucketService.user?.id
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
    
    func matchRemote(url: URL) -> Bool
    {
      let link = request.fromRef.repository
                        .links?.clone?.first { $0.name == url.scheme }
      
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
                               .index(where: { $0.user.slug == userID })
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
    responseResource.useData(owner: self) {
      (entity: Entity<Any>) in
      guard let user = entity.content as? BitbucketServer.User
      else {
        self.authenticationStatus = .failed(nil)
        return
      }
      
      self.user = user
    }
  }
  
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
  func match(remote: Remote) -> Bool
  {
    let host = remote.url?.host
    
    return host == baseURL?.host
  }
}

extension BitbucketServerAPI: PullRequestService
{
  var userID: String { return user?.slug ?? "" }
  
  func getPullRequests(callback: @escaping ([Xit.PullRequest]) -> Void)
  {
    pullRequests().useData(owner: self) {
      (entity: Entity<Any>) in
      guard let requests = entity.content as? BitbucketServer.PagedPullRequest
      else {
        callback([])
        return
      }
      
      let result = requests.values.map { PullRequest(request: $0,
                                                     bitbucketService: self) }
      
      #if DEBUG
      for request in result {
        print("\(request.status): \(request.displayName)")
      }
      #endif
      callback(result)
    }
  }
  
  func pullRequestPath(_ request: PullRequest) -> String
  {
    let projectKey = request.request.toRef.repository.project.key
    let repoSlug = request.request.toRef.repository.slug
    let requestID = request.request.id
    
    return "projects/\(projectKey)/repos/\(repoSlug)/pull-requests/\(requestID)/"
  }
  
  func update(request: PullRequest, approved: Bool,
              status: BitbucketServer.ReviewerStatus,
              onSuccess: @escaping () -> Void,
              onFailure: @escaping (RequestError) -> Void)
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

    resource.request(.put, json: data).onCompletion {
      (info) in
      switch info.response {
        case .success:
          onSuccess()
        case .failure(let error):
          onFailure(error)
      }
    }
  }
  
  func approve(request: Xit.PullRequest,
               onSuccess: @escaping () -> Void,
               onFailure: @escaping (RequestError) -> Void)
  {
    guard let bbRequest = request as? PullRequest
    else { return }
    
    update(request: bbRequest, approved: true, status: .approved,
           onSuccess: onSuccess, onFailure: onFailure)
  }
  
  func unapprove(request: Xit.PullRequest,
                 onSuccess: @escaping () -> Void,
                 onFailure: @escaping (RequestError) -> Void)
  {
    guard let bbRequest = request as? PullRequest
    else { return }
    
    update(request: bbRequest, approved: false, status: .unapproved,
           onSuccess: onSuccess, onFailure: onFailure)
  }
  
  func needsWork(request: Xit.PullRequest,
                 onSuccess: @escaping () -> Void,
                 onFailure: @escaping (RequestError) -> Void)
  {
    guard let bbRequest = request as? PullRequest
    else { return }
    
    update(request: bbRequest, approved: false, status: .needsWork,
           onSuccess: onSuccess, onFailure: onFailure)
  }
  
  func merge(request: Xit.PullRequest)
  {
    guard let request = request as? PullRequest
    else {
      // error
      return
    }
    let resource = self.resource(pullRequestPath(request) + "merge")
    
    resource.request(.post).onCompletion {
      (_) in
      // to be implemented
    }
  }
}
