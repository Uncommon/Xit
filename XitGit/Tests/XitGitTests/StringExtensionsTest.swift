import XCTest
@testable import XitGit

final class StringExtensionsTest: XCTestCase
{
  func testPrefix()
  {
    XCTAssertEqual("none".droppingPrefix("1"), "none")
    XCTAssertEqual("embiggen".droppingPrefix("em"), "biggen")
  }
  
  func testSplitRefName() throws
  {
    XCTAssertNil("none".splitRefName())
    
    let (prefix, name) = try XCTUnwrap("refs/heads/spunk".splitRefName())
    
    XCTAssertEqual(prefix, "refs/heads/")
    XCTAssertEqual(name, "spunk")
  }
}
