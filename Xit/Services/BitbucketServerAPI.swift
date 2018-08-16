import Foundation
import Siesta

enum BitbucketServer
{
  struct PagedResponse<T> : Codable where T: Codable
  {
    let size, limit, start: Int
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
  }

  struct Project: Codable
  {
    let key: String
  }

  struct Repository: Codable
  {
    let slug: String
    let name: String?
    let project: Project
  }

  struct Ref: Codable
  {
    let id: String
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
  
  struct Reviewer: Codable
  {
    let user: User
    let lastReviewedCommit: String
    let role: ReviewerRole
    let approved: Bool
    let status: ReviewerStatus
  }
  
  struct Link: Codable, Equatable
  {
    let href: String
  }
  
  struct Links: Codable, Equatable
  {
    let `self`: [Link]
  }
  
  struct Participant: Codable
  {
    let user: User
    let role: ReviewerRole
    let approved: Bool
    let status: ReviewerStatus
  }

  struct PullRequest: Codable
  {
    let id: Int
    let version: Int
    let title: String
    let description: String
    let state: PullRequestState
    let open: Bool
    let closed: Bool
    let createdDate, updatedDate: Int // convert to date
    let fromRef, toRef: Ref
    let locked: Bool
    let author: User
    let reviewers: [Reviewer]
    let participants: [Participant]
    let links: Links
  }
}

class BitbucketServerAPI: BasicAuthService, ServiceAPI
{
  var type: AccountType { return .bitbucketServer }
  var user: BitbucketServer.User?
  static let rootPath = "/rest/api/1.0"
  
  init?(user: String, password: String, baseURL: String?)
  {
    guard let baseURL = baseURL,
          var fullBaseURL = URLComponents(string: baseURL)
    else { return nil }
    
    fullBaseURL.path = BitbucketServerAPI.rootPath
    
    super.init(user: user, password: password, baseURL: fullBaseURL.string,
               authenticationPath: "users/\(user)")
    
    
    
    configureTransformer("/users/*") {
      (entity: Entity<Data>) -> BitbucketServer.User? in
      do {
        return try JSONDecoder().decode(BitbucketServer.User.self,
                                        from: entity.content)
      }
      catch let error as DecodingError {
        print(error.context.debugDescription)
        throw error
      }
    }
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
