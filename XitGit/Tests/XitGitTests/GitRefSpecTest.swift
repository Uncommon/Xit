import XCTest
@testable import XitGit

final class GitRefSpecTest: XCTestCase
{
  override class func setUp()
  {
    super.setUp()
    XTRepository.initialize()
  }

  func testGitRefSpecTransformNoMatchReturnsNil() throws
  {
    let refSpec = try XCTUnwrap(
      GitRefSpec(string: "refs/heads/main:refs/remotes/origin/main",
                 isFetch: true))

    XCTAssertEqual(refSpec.transformToTarget(name: "refs/heads/main"),
                   "refs/remotes/origin/main")
    XCTAssertNil(refSpec.transformToTarget(name: "refs/tags/v1.0.0"))
  }
}
