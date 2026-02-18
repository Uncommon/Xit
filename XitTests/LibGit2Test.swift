import XCTest
import Clibgit2

final class LibGit2Test: XCTestCase
{
  func testFlags() throws
  {
    let features = git_libgit2_features()
    
    XCTAssert(features & Int32(GIT_FEATURE_SSH.rawValue) != 0,
              "libssh2 is missing")
    XCTAssert(features & Int32(GIT_FEATURE_HTTPS.rawValue) != 0,
              "https is missing")
  }
}
