import XCTest
@testable import Xit

class TrailersTest: XCTestCase
{
  func testParse() throws
  {
    let message = """
          Text at the beginning

          Tested-by: This Guy
          """
    let commit = FakeCommit(parentOIDs: [], message: message, authorSig: nil, committerSig: nil, email: nil, tree: nil, oid: "aaa")

    let trailers = commit.parseTrailers()

    XCTAssertEqual(trailers.count, 1)
    XCTAssertEqual(trailers[0].0, "Tested-by")
    XCTAssertEqual(trailers[0].1, "This Guy")
  }
}
