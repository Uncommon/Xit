import XCTest
@testable import Xit

class StringExtensionsTest: XCTestCase
{
  func testPrefix()
  {
    XCTAssertEqual("none".removingPrefix("1"), "none")
    XCTAssertEqual("embiggen".removingPrefix("em"), "biggen")
  }
  
  func testSplitRefName()
  {
    XCTAssertNil("none".splitRefName())
    
    let (prefix, name) = "refs/heads/spunk".splitRefName()!
    
    XCTAssertEqual(prefix, "refs/heads/")
    XCTAssertEqual(name, "spunk")
  }
}
