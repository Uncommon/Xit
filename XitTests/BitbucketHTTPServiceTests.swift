import Foundation
import Testing
@testable import Xit

@Suite("BitbucketHTTPService")
struct BitbucketHTTPServiceTests
{
  private func makeService(mock: MockNetworkService) -> BitbucketHTTPService
  {
    let account = Account(type: .bitbucketServer,
                          user: "jsmith",
                          location: URL(string: "https://example.com")!,
                          id: UUID())
    
    // The service appends the root path during init
    return BitbucketHTTPService(account: account,
                                password: "pw",
                                passwordStorage: MemoryPasswordStorage.shared,
                                networkService: mock)!
  }
  
  private func sampleUserJSON() -> Data
  {
    """
    {
      "name": "jsmith",
      "emailAddress": "jsmith@example.com",
      "id": 7,
      "displayName": "Jane Smith",
      "active": true,
      "slug": "jsmith",
      "type": "NORMAL",
      "links": {"self": [{"href": "https://example.com/users/jsmith"}]}
    }
    """.data(using: .utf8)!
  }
  
  private func samplePullRequestsJSON() -> Data
  {
    """
    {
      "size": 1,
      "limit": 25,
      "isLastPage": true,
      "values": [
        {
          "id": 1,
          "version": 1,
          "title": "Fix bug",
          "description": "Bug fix PR",
          "state": "OPEN",
          "open": true,
          "closed": false,
          "closedDate": null,
          "createdDate": 1700000000000,
          "updatedDate": 1700000001000,
          "fromRef": {
            "id": "refs/heads/feature",
            "displayId": "feature",
            "latestCommit": "abc",
            "repository": {
              "slug": "repo",
              "name": "repo",
              "project": {"key": "PRJ", "id": 1, "links": {"self": []}, "name": "PRJ", "public": false, "type": "NORMAL"},
              "links": {
                "self": [{"href": "https://example.com/projects/PRJ/repos/repo"}],
                "clone": [
                  {"href": "https://example.com/scm/prj/repo.git", "name": "https"},
                  {"href": "ssh://git@example.com:7999/prj/repo.git", "name": "ssh"}
                ]
              },
              "forkable": true,
              "id": 99,
              "public": false,
              "scmId": "git",
              "statusMessage": null
            }
          },
          "toRef": {
            "id": "refs/heads/main",
            "displayId": "main",
            "latestCommit": "def",
            "repository": {
              "slug": "repo",
              "name": "repo",
              "project": {"key": "PRJ", "id": 1, "links": {"self": []}, "name": "PRJ", "public": false, "type": "NORMAL"},
              "links": {"self": [], "clone": []},
              "forkable": true,
              "id": 99,
              "public": false,
              "scmId": "git",
              "statusMessage": null
            }
          },
          "locked": false,
          "author": {
            "user": {
              "name": "author",
              "emailAddress": "author@example.com",
              "id": 3,
              "displayName": "Author",
              "active": true,
              "slug": "author",
              "type": "NORMAL",
              "links": {"self": [{"href": "https://example.com/users/author"}]}
            },
            "role": "AUTHOR",
            "approved": false,
            "status": "UNAPPROVED",
            "lastReviewedCommit": null
          },
          "reviewers": [
            {
              "user": {
                "name": "jsmith",
                "emailAddress": "jsmith@example.com",
                "id": 7,
                "displayName": "Jane Smith",
                "active": true,
                "slug": "jsmith",
                "type": "NORMAL",
                "links": {"self": [{"href": "https://example.com/users/jsmith"}]}
              },
              "role": "REVIEWER",
              "approved": false,
              "status": "UNAPPROVED",
              "lastReviewedCommit": null
            }
          ],
          "participants": [],
          "links": {
            "self": [{"href": "https://example.com/projects/PRJ/repos/repo/pull-requests/1"}],
            "clone": []
          }
        }
      ]
    }
    """.data(using: .utf8)!
  }
  
  private func pagedPullRequestsJSON(start: Int?, isLastPage: Bool, ids: [Int]) -> Data
  {
    let values = ids.map {
      id in
      """
      {
        "id": \(id),
        "version": 1,
        "title": "PR \(id)",
        "description": "",
        "state": "OPEN",
        "open": true,
        "closed": false,
        "closedDate": null,
        "createdDate": 1700000000000,
        "updatedDate": 1700000001000,
        "fromRef": {
          "id": "refs/heads/feature",
          "displayId": "feature",
          "latestCommit": "abc",
          "repository": {
            "slug": "repo",
            "name": "repo",
            "project": {"key": "PRJ", "id": 1, "links": {"self": []}, "name": "PRJ", "public": false, "type": "NORMAL"},
            "links": {"self": [{"href": "https://example.com/projects/PRJ/repos/repo"}], "clone": []},
            "forkable": true,
            "id": 99,
            "public": false,
            "scmId": "git",
            "statusMessage": null
          }
        },
        "toRef": {
          "id": "refs/heads/main",
          "displayId": "main",
          "latestCommit": "def",
          "repository": {
            "slug": "repo",
            "name": "repo",
            "project": {"key": "PRJ", "id": 1, "links": {"self": []}, "name": "PRJ", "public": false, "type": "NORMAL"},
            "links": {"self": [], "clone": []},
            "forkable": true,
            "id": 99,
            "public": false,
            "scmId": "git",
            "statusMessage": null
          }
        },
        "locked": false,
        "author": {"user": {"name": "author", "emailAddress": "author@example.com", "id": 3, "displayName": "Author", "active": true, "slug": "author", "type": "NORMAL", "links": {"self": [{"href": "https://example.com/users/author"}]}}, "role": "AUTHOR", "approved": false, "status": "UNAPPROVED", "lastReviewedCommit": null},
        "reviewers": [],
        "participants": [],
        "links": {"self": [{"href": "https://example.com/projects/PRJ/repos/repo/pull-requests/\(id)"}], "clone": []}
      }
      """
    }.joined(separator: ",")
    let startField = start.map { "\"start\": \($0)," } ?? ""
    let json = """
    {\n\(startField)
      "size": \(ids.count),
      "limit": 1,
      "isLastPage": \(isLastPage ? "true" : "false"),
      "values": [\n        \(values)\n      ]
    }
    """
    return json.data(using: .utf8)!
  }
  
  @Test
  func getPullRequestsDecodesAndSetsFields() async throws
  {
    let mock = MockNetworkService()
    let service = makeService(mock: mock)
    
    await service.didAuthenticate(data: sampleUserJSON())
    mock.setNextResponse(data: samplePullRequestsJSON())
    
    let prs = await service.getPullRequests()
    try #require(prs.count == 1)
    let pr = try #require(prs.first as? BitbucketHTTPService.BitbucketPR)
    
    #expect(pr.id == "1")
    #expect(pr.displayName == "Fix bug")
    #expect(pr.sourceBranch == "refs/heads/feature")
    #expect(pr.webURL == URL(string: "https://example.com/projects/PRJ/repos/repo/pull-requests/1"))
    #expect(pr.sourceRepo == URL(string: "https://example.com/scm/prj/repo.git"))
    #expect(pr.availableActions.contains(.approve))
  }
  
  private func decodeBody(_ endpoint: Endpoint) throws -> [String: Any]
  {
    guard let body = endpoint.body else { return [:] }
    
    return try JSONSerialization.jsonObject(with: body) as? [String: Any] ?? [:]
  }
  
  @Test
  func approveAndStateUpdatesSendPutWithPayload() async throws
  {
    let mock = MockNetworkService()
    let service = makeService(mock: mock)
    await service.didAuthenticate(data: sampleUserJSON())
    mock.responseQueue = [.success(samplePullRequestsJSON())]
    // Responses for approve, unapprove, needsWork (empty bodies are fine)
    mock.enqueueResponse(data: Data())
    mock.enqueueResponse(data: Data())
    mock.enqueueResponse(data: Data())
    let prs = await service.getPullRequests()
    let pr = try #require(prs.first as? BitbucketHTTPService.BitbucketPR)
    
    try await service.approve(request: pr)
    let approveRequest = try #require(mock.lastRequest)
    let approveBody = try decodeBody(approveRequest)
    
    #expect(approveRequest.path.contains("participants/jsmith"))
    #expect(approveBody["approved"] as? Bool == true)
    #expect(approveBody["status"] as? String == BitbucketServer.ReviewerStatus.approved.rawValue)
    
    try await service.unapprove(request: pr)
    let unapproveRequest = try #require(mock.lastRequest)
    let unapproveBody = try decodeBody(unapproveRequest)
    
    #expect(unapproveBody["approved"] as? Bool == false)
    #expect(unapproveBody["status"] as? String == BitbucketServer.ReviewerStatus.unapproved.rawValue)
    
    try await service.needsWork(request: pr)
    let needsWorkRequest = try #require(mock.lastRequest)
    let needsWorkBody = try decodeBody(needsWorkRequest)
    
    #expect(needsWorkBody["approved"] as? Bool == false)
    #expect(needsWorkBody["status"] as? String == BitbucketServer.ReviewerStatus.needsWork.rawValue)
  }
  
  @Test
  func mergeSendsPostToMergeEndpoint() async throws
  {
    let mock = MockNetworkService()
    let service = makeService(mock: mock)
    await service.didAuthenticate(data: sampleUserJSON())
    mock.responseQueue = [.success(samplePullRequestsJSON())]
    let prs = await service.getPullRequests()
    let pr = try #require(prs.first)
    
    // Merge call expects a response body; supply empty data
    mock.setNextResponse(data: Data())
    try await service.merge(request: pr)
    let mergeRequest = try #require(mock.lastRequest)
    
    #expect(mergeRequest.path.hasSuffix("/pull-requests/1/merge"))
    #expect(mergeRequest.method == .post)
  }
  
  @Test
  func getPullRequestsPaginatesThroughResults() async throws
  {
    let mock = MockNetworkService()
    let service = makeService(mock: mock)
    await service.didAuthenticate(data: sampleUserJSON())
    mock.responseQueue = [
      .success(pagedPullRequestsJSON(start: 0, isLastPage: false, ids: [1])),
      .success(pagedPullRequestsJSON(start: 1, isLastPage: true, ids: [2]))
    ]
    let prs = await service.getPullRequests()
    
    #expect(prs.count == 2)
    #expect(mock.requestCount == 2)
    #expect(mock.requests.first?.queryItems?.isEmpty ?? true)
    let secondStart = mock.requests.dropFirst().first?.queryItems?.first { $0.name == "start" }?.value
    #expect(secondStart == "1")
  }
}
