import XCTest
@testable import Xit
@testable import XitGit

final class PullRequestCacheTest: XCTestCase
{
  final class ClientSpy: PullRequestClient
  {
    var updates: [(branch: String, requestIDs: [String])] = []

    func pullRequestUpdated(branch: String, requests: [PullRequest])
    {
      updates.append((branch: branch, requestIDs: requests.map(\.id)))
    }
  }

  func testPullRequestCacheUpdateStatusMutatesAndNotifiesOnce()
  {
    let repo = FakeRepo()
    let cache = PullRequestCache(repository: repo)
    let client = ClientSpy()
    let request = FakePullRequest(
      serviceID: .init(),
      availableActions: [],
      sourceBranch: "refs/heads/branch1",
      sourceRepo: repo.remote1.url,
      displayName: "PR1",
      id: "1",
      authorName: "Author",
      status: .open,
      webURL: URL(string: "https://example.com/pr/1"))

    cache.add(client: client)
    cache.add(client: client) // should be ignored as duplicate
    cache.requests = [request]

    cache.update(pullRequestID: "1", status: .merged)

    XCTAssertEqual(cache.requests.first?.status, .merged)
    XCTAssertEqual(client.updates.count, 1)
    XCTAssertEqual(client.updates.first?.branch, "refs/heads/branch1")
    XCTAssertEqual(client.updates.first?.requestIDs, ["1"])

    cache.update(pullRequestID: "404", status: .inactive)
    XCTAssertEqual(client.updates.count, 1)
  }
}
