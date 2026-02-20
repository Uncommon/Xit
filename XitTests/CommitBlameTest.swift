import XCTest
import XitGit
@testable import Xit

class CommitBlameTest: XTTest
{
  let elements1 = ["Antimony",
                   "Arsenic",
                   "Aluminum",
                   "Selenium",
                   "Hydrogen",
                   "Oxygen",
                   "Nitrogen",
                   "Rhenium"]
  let elements2 = ["Antimony",
                   "Arsenic",
                   "Aluminum**",
                   "Selenium**",
                   "Hydrogen",
                   "Oxygen",
                   "Nitrogen",
                   "Rhenium"]
  let elements3 = ["Antimony",
                   "Arsenic",
                   "Aluminum**",
                   "Selenium**",
                   "Hydrogen++",
                   "Oxygen",
                   "Nitrogen",
                   "Rhenium"]
  var blamePath: String!

  override func setUpWithError() throws
  {
    try super.setUpWithError()
    
    blamePath = repository.repoURL.path.appending(pathComponent: TestFileName.blame.rawValue)
    try execute(in: repository) {
      CommitFiles("first") {
        Write(elements1.joined(separator: "\n"), to: .blame)
      }
      CommitFiles("second") {
        Write(elements2.joined(separator: "\n"), to: .blame)
      }
      CommitFiles("third") {
        Write(elements3.joined(separator: "\n"), to: .blame)
      }
    }
  }
  
  func testCommitBlame() throws
  {
    let headSHA = try XCTUnwrap(repository.headSHA)
    let headCommit = try XCTUnwrap(GitCommit(sha: headSHA, repository: repository.gitRepo))
    let headOID = try XCTUnwrap(GitOID(sha: headSHA))
    let commitModel = CommitSelection(repository: repository,
                                    commit: headCommit)
    let commitBlame = try XCTUnwrap(commitModel.fileList.blame(for: TestFileName.blame.rawValue))
    let lineStarts = [1, 3, 5, 6]
    let lineCounts = [2, 2, 1, 3]
    
    XCTAssertEqual(commitBlame.hunks.count, 4)
    XCTAssertEqual(commitBlame.hunks.map { $0.finalLine.start }, lineStarts)
    XCTAssertEqual(commitBlame.hunks.map { $0.lineCount }, lineCounts)
    XCTAssertEqual(commitBlame.hunks[2].finalLine.oid, headOID)
  }
  
}
