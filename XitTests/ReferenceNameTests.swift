import XCTest
@testable import Xit

final class ReferenceNameTests: XCTestCase
{
  func testInit()
  {
    XCTAssertNil(LocalBranchRefName(rawValue: "/"))
    XCTAssertNil(LocalBranchRefName("/"))
    XCTAssertNil(LocalBranchRefName(rawValue: "refs/tags/branch"))
    XCTAssertNil(RemoteBranchRefName(remote: "origin", branch: "/oops"))

    XCTAssertNotNil(LocalBranchRefName(rawValue: "refs/heads/branch"))
    XCTAssertNotNil(LocalBranchRefName("branch"))
    XCTAssertNotNil(RemoteBranchRefName(remote: "origin", branch: "branch"))
    XCTAssertNotNil(TagRefName(rawValue: "refs/tags/marker"))
    
    let ref = "refs/heads/branch"
    
    XCTAssertEqual(LocalBranchRefName(rawValue: ref)?.rawValue, ref)
  }
}
