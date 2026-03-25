import XCTest
@testable import Xit

final class XitGitBasicTests: XCTestCase
{
  func testSanity()
  {
    XCTAssertTrue(RepoError.genericGitError.isExpected)
  }
}
