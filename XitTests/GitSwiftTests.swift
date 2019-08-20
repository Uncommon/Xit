import XCTest
@testable import Xit

class GitSwiftTests: XCTestCase
{
  func check(strings: [String])
  {
    strings.withGitStringArray {
      (strarray) in
      XCTAssertEqual(strarray.count, strings.count)
      for (index, string) in strings.enumerated() {
        let copiedString = String(validatingUTF8:strarray.strings[index]!)!
        
        XCTAssertEqual(copiedString, string)
      }
    }
  }
  
  func testWithStringArray()
  {
    let single = ["one"]
    let double = ["one", "two"]
    
    check(strings: single)
    check(strings: double)
  }
}
