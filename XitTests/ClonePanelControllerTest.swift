import XCTest
@testable import Xit

final class ClonePanelControllerTest: XCTestCase
{
  func testValidateURLAcceptsAndRejectsExpectedForms() throws
  {
    let acceptedURLs: [URL] = [
      URL(fileURLWithPath: "/tmp/repo"),
      try XCTUnwrap(URL(string: "https://github.com/owner/repo.git")),
      try XCTUnwrap(URL(string: "ssh://git@github.com/owner/repo.git")),
    ]

    for url in acceptedURLs {
      XCTAssertTrue(ClonePanelController.validate(url: url),
                    "Expected accepted URL: \(url.absoluteString)")
    }

    var emptyPath = URLComponents()
    emptyPath.scheme = "https"
    emptyPath.host = "github.com"

    var noHost = URLComponents()
    noHost.scheme = "ssh"
    noHost.path = "/owner/repo.git"

    let rejectedURLs: [URL] = [
      try XCTUnwrap(emptyPath.url),
      try XCTUnwrap(noHost.url),
      try XCTUnwrap(URL(string: "github.com/owner/repo.git")),
    ]

    for url in rejectedURLs {
      XCTAssertFalse(ClonePanelController.validate(url: url),
                     "Expected rejected URL: \(url.absoluteString)")
    }
  }
}
