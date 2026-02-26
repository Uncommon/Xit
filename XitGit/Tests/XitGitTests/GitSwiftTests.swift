import XCTest
@testable import XitGit

class GitSwiftTests: XCTestCase
{
  override class func setUp()
  {
    super.setUp()
    XTRepository.initialize()
  }

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
  
  func testPrettifySimple()
  {
    let message = "simple"
    let expected = "simple\n"

    XCTAssertEqual(expected, message.prettifiedMessage(stripComments: false))
    XCTAssertEqual(expected, message.prettifiedMessage(stripComments: true))
  }
  
  func testPrettifyWhitespace()
  {
    let message = "\nmessage "
    // If there are any newlines, prettify ensures a newline at the end
    let expected = "message\n"
    
    XCTAssertEqual(expected, message.prettifiedMessage(stripComments: false))
    XCTAssertEqual(expected, message.prettifiedMessage(stripComments: true))
  }
  
  func testPrettifyComment()
  {
    let message = """
      first line
      # comment
      second line
      """
    let stripped = """
      first line
      second line

      """
    let notStripped = """
      first line
      # comment
      second line

      """

    XCTAssertEqual(stripped, message.prettifiedMessage(stripComments: true))
    XCTAssertEqual(notStripped, message.prettifiedMessage(stripComments: false))
  }
}
