import XCTest
@testable import Xit
@testable import XitGit

final class HistorySearchTest: XCTestCase
{
  private func makeCommit(_ id: GitOID,
                          message: String,
                          author: String? = nil,
                          authorEmail: String? = nil,
                          committer: String? = nil,
                          committerEmail: String? = nil) -> StringCommit
  {
    let timestamp = Date(timeIntervalSince1970: 0)

    return .init(parentOIDs: [],
                 message: message,
                 authorSig: Signature(name: author,
                                      email: authorEmail,
                                      when: timestamp),
                 committerSig: Signature(name: committer,
                                         email: committerEmail,
                                         when: timestamp),
                 id: id)
  }

  func testSearchDownFindsNextSummaryMatch()
  {
    let commits = [
      makeCommit("1", message: "setup"),
      makeCommit("2", message: "add widgets"),
      makeCommit("3", message: "fix widgets"),
      makeCommit("4", message: "finalize"),
    ]

    let index = HistorySearch.matchingIndex(in: commits,
                                            selectedIndex: 0,
                                            text: "WIDGETS",
                                            type: .summary,
                                            direction: .down)

    XCTAssertEqual(index, 1)
  }

  func testSearchUpFindsPreviousSummaryMatch()
  {
    let commits = [
      makeCommit("1", message: "setup"),
      makeCommit("2", message: "add widgets"),
      makeCommit("3", message: "fix widgets"),
      makeCommit("4", message: "finalize"),
    ]

    let index = HistorySearch.matchingIndex(in: commits,
                                            selectedIndex: 3,
                                            text: "widgets",
                                            type: .summary,
                                            direction: .up)

    XCTAssertEqual(index, 2)
  }

  func testSummarySearchUsesSubjectLineOnly()
  {
    let commits = [
      makeCommit("1", message: "subject only\nbody mentions asd"),
      makeCommit("2", message: "asd in subject"),
    ]

    let index = HistorySearch.matchingIndex(in: commits,
                                            selectedIndex: -1,
                                            text: "asd",
                                            type: .summary,
                                            direction: .down)

    XCTAssertEqual(index, 1)
  }

  func testAuthorSearchMatchesNameAndEmailCaseInsensitively()
  {
    let commits = [
      makeCommit("1", message: "one",
                 author: "Someone Else",
                 authorEmail: "else@example.com"),
      makeCommit("2", message: "two",
                 author: "Danny Greg",
                 authorEmail: "Danny@Sample.test"),
    ]

    let nameIndex = HistorySearch.matchingIndex(in: commits,
                                                selectedIndex: -1,
                                                text: "danny",
                                                type: .author,
                                                direction: .down)
    let emailIndex = HistorySearch.matchingIndex(in: commits,
                                                 selectedIndex: -1,
                                                 text: "SAMPLE.TEST",
                                                 type: .author,
                                                 direction: .down)

    XCTAssertEqual(nameIndex, 1)
    XCTAssertEqual(emailIndex, 1)
  }

  func testCommitterSearchMatchesCaseInsensitively()
  {
    let commits = [
      makeCommit("1", message: "one", committer: "Bot Builder"),
      makeCommit("2", message: "two", committer: "Release Manager"),
    ]

    let index = HistorySearch.matchingIndex(in: commits,
                                            selectedIndex: -1,
                                            text: "release",
                                            type: .committer,
                                            direction: .down)

    XCTAssertEqual(index, 1)
  }

  func testSHASearchMatchesPrefixCaseInsensitively()
  {
    let commits = [
      makeCommit("abcdef1234567890abcdef1234567890abcdef12", message: "one"),
      makeCommit("1234567890abcdef1234567890abcdef12345678", message: "two"),
    ]

    let index = HistorySearch.matchingIndex(in: commits,
                                            selectedIndex: -1,
                                            text: "ABC",
                                            type: .sha,
                                            direction: .down)

    XCTAssertEqual(index, 0)
  }

  func testEmptySearchDoesNotMatch()
  {
    let commits = [
      makeCommit("1", message: "one"),
      makeCommit("2", message: "two"),
    ]

    XCTAssertNil(HistorySearch.matchingIndex(in: commits,
                                             selectedIndex: -1,
                                             text: "   ",
                                             type: .summary,
                                             direction: .down))
  }
}
