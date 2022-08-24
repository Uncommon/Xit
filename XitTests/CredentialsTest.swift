import XCTest
@testable import Xit

class CredentialsTest: XCTestCase
{
  func token(_ name: String) throws -> String
  {
    guard let token = externalFileContent(name)
    else {
      throw XCTSkip("file \(name) not available")
    }
    return token
  }

  func testAuthenticateRemote() throws
  {
    let cases: [(name: String, url: String, branch: String,
                 user: String, token: String)] = [
      (name: "Bitbucket", url: "https://dathorc@bitbucket.org/dathorc/test1.git",
       branch: "main",
       user: "dathorc", token: try token("bitbucket_token.txt")),
      (name: "GitHub", url: "https://github.com/Uncommon/Testing.git",
       branch: "master",
       user: "Uncommon", token: try token("github_token.txt")),
    ]

    for testCase in cases {
      xitTestLogger.info("case: \(testCase.name)")
      func getPassword() -> (String, String)?
      { (testCase.user, testCase.token) }
      let url = try XCTUnwrap(URL(string: testCase.url))
      let remote = try XCTUnwrap(GitRemote(url: url))
      let callbacks = RemoteCallbacks(passwordBlock: getPassword,
                                      passwordStorage: NoOpKeychain())
      let expectation = expectation(description: "access remote")
      var result: Result<String?, Error>?

      DispatchQueue.global().async {
        result = .init(catching: {
          try remote.withConnection(direction: .fetch,
                                    callbacks: callbacks) {
            $0.defaultBranch
          }
        })
        expectation.fulfill()
      }
      wait(for: [expectation], timeout: 5)

      do {
        let result = try XCTUnwrap(result)
        let branch = try result.get()

        XCTAssertEqual(branch, testCase.branch)
      }
      catch let error as RepoError {
        XCTFail(error.description)
      }
      catch let error {
        XCTFail(error.localizedDescription)
      }
    }
  }
}
