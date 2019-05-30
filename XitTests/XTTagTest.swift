import XCTest
@testable import Xit

let message = "testing"
let tagName = "testTag"

class XTTagTest: XTTest
{
  func testAnnotatedTag()
  {
    _ = try! repository.executeGit(args: ["tag", "-a", tagName, "-m", message],
                                   writes: true)
    checkTag(hasMessage: true)
  }
  
  func testLightweightTag()
  {
    _ = try! repository.executeGit(args: ["tag", tagName],
                                   writes: true)
    checkTag(hasMessage: false)
  }
  
  // The message comes through with an extra newline at the end
  func trimmedMessage(tag: Tag) -> String
  {
    return (tag.message! as NSString)
           .trimmingCharacters(in: CharacterSet.newlines)
  }
  
  func checkTag(hasMessage: Bool)
  {
    guard let tag = GitTag(repository: repository, name:tagName)
    else {
      XCTFail("tag not found")
      return
    }
    XCTAssertNotNil(tag.targetOID)
    if hasMessage {
      XCTAssertEqual(trimmedMessage(tag: tag), message)
    }
    
    guard let fullTag = GitTag(repository: repository,
                               name: "refs/tags/" + tagName)
    else {
      XCTFail("tag not found by full name")
      return
    }
    XCTAssertNotNil(fullTag.targetOID)
    if hasMessage {
      XCTAssertEqual(trimmedMessage(tag: fullTag), message)
    }
  }
}
