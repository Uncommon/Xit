import XCTest
@testable import Xit

class StringExtensionsTest: XCTestCase
{
  func testPrefix()
  {
    XCTAssertEqual("none".droppingPrefix("1"), "none")
    XCTAssertEqual("embiggen".droppingPrefix("em"), "biggen")
  }
  
  func testSplitRefName()
  {
    XCTAssertNil("none".splitRefName())
    
    let (prefix, name) = "refs/heads/spunk".splitRefName()!
    
    XCTAssertEqual(prefix, "refs/heads/")
    XCTAssertEqual(name, "spunk")
  }
}
