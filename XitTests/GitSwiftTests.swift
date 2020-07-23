import XCTest
@testable import Xit

class GitSwiftTests: XCTestCase
{
  func check(strings: [String]) throws
  {
    try strings.withGitStringArray {
      (strarray) in
      XCTAssertEqual(strarray.count, strings.count)
      for (index, string) in strings.enumerated() {
        let copiedString = try XCTUnwrap(String(validatingUTF8:strarray.strings[index]!))
        
        XCTAssertEqual(copiedString, string)
      }
    }
  }
  
  func testWithStringArray() throws
  {
    let single = ["one"]
    let double = ["one", "two"]
    
    try check(strings: single)
    try check(strings: double)
  }
}
