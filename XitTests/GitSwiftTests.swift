import XCTest
@testable import Xit

class GitSwiftTests: XCTestCase
{
  func check(strings: [String])
  {
    withGitStringArray(from: strings) {
      (strarray) in
      var localArray = strarray
      let copy = UnsafeMutablePointer<git_strarray>.allocate(capacity: 1)
      
      git_strarray_copy(copy, &localArray)
      XCTAssertEqual(copy.pointee.count, strings.count)
      for (index, string) in strings.enumerated() {
        let copiedString = String(validatingUTF8:copy.pointee.strings[index]!)!
        
        XCTAssertEqual(copiedString, string)
      }
      git_strarray_free(copy)
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
