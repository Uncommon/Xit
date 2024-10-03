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
  }

  func testBranchRef() throws
  {
    let refName = "refs/heads/branch"
    let branchRef = try XCTUnwrap(LocalBranchRefName(rawValue: refName))

    XCTAssertEqual(branchRef.fullPath, refName)
    XCTAssertEqual(branchRef.name, "branch")
    XCTAssertEqual(branchRef.localName, "branch")
  }

  func testRemoteRef() throws
  {
    let refName = "refs/remotes/origin/branch"
    let remoteRef = try XCTUnwrap(RemoteBranchRefName(rawValue: refName))

    XCTAssertEqual(remoteRef.fullPath, refName)
    XCTAssertEqual(remoteRef.remoteName, "origin")
    XCTAssertEqual(remoteRef.name, "origin/branch")
    XCTAssertEqual(remoteRef.localName, "branch")
  }
}
