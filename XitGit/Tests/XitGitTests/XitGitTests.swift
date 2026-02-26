import XCTest
@testable import XitGit

final class XitGitBasicTests: XCTestCase
{
  func testSanity()
  {
    XCTAssertTrue(RepoError.genericGitError.isExpected)
  }
}
