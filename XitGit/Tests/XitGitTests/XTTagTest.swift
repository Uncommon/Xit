import XCTest
@testable import XitGit

let message = "testing"
let tagName = "testTag"

class XTTagTest: XTTest
{
  func testAnnotatedTag() throws
  {
    _ = try repository.executeGit(args: ["tag", "-a", tagName, "-m", message],
                                  writes: true)
    try checkTag(hasMessage: true)
  }
  
  func testLightweightTag() throws
  {
    _ = try repository.executeGit(args: ["tag", tagName],
                                  writes: true)
    try checkTag(hasMessage: false)
  }
  
  // The message comes through with an extra newline at the end
  func trimmedMessage(tag: any Tag) -> String
  {
    return (tag.message! as NSString)
           .trimmingCharacters(in: CharacterSet.newlines)
  }
  
  func checkTag(hasMessage: Bool) throws
  {
    let tag = try XCTUnwrap(GitTag(repository: repository, name:tagName),
                            "tag not found")

    XCTAssertNotNil(tag.targetOID)
    if hasMessage {
      XCTAssertEqual(trimmedMessage(tag: tag), message)
    }
    
    let fullTag = try XCTUnwrap(GitTag(repository: repository,
                                       name: "refs/tags/" + tagName),
                                "tag not found by full name")

    XCTAssertNotNil(fullTag.targetOID)
    if hasMessage {
      XCTAssertEqual(trimmedMessage(tag: fullTag), message)
    }
  }
}
