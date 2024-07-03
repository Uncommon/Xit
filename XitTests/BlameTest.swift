import XCTest
@testable import Xit

class BlameTest: XTTest
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
  
  func testStagingBlame() throws
  {
    var elements4 = elements3
    
    elements4[0].append("!!")
    try execute(in: repository) {
      Write(elements4.joined(separator: "\n"), to: .blame)
      Stage(.blame)
    }

    var elements5 = elements4
    
    elements5[7].append("##")
    try execute(in: repository) {
      Write(elements5.joined(separator: "\n"), to: .blame)
    }

    let stagingModel = StagingSelection(repository: repository, amending: false)
    let unstagedBlame = try XCTUnwrap(stagingModel.unstagedFileList.blame(for: TestFileName.blame.rawValue),
                                      "can't get unstaged blame")
    let unstagedStarts = [1, 2, 3, 5, 6, 8]
    
    XCTAssertEqual(unstagedBlame.hunks.count, 6)
    XCTAssertEqual(unstagedBlame.hunks.map { $0.finalLine.start }, unstagedStarts)
    XCTAssertTrue(unstagedBlame.hunks.first?.finalLine.oid.isZero ?? false)
    XCTAssertTrue(unstagedBlame.hunks.last?.finalLine.oid.isZero ?? false)
    
    let stagedBlame = try XCTUnwrap(stagingModel.fileList.blame(for: TestFileName.blame.rawValue),
                                    "can't get staged blame")
    let stagedStarts = [1, 2, 3, 5, 6]
    
    XCTAssertEqual(stagedBlame.hunks.count, 5)
    XCTAssertEqual(stagedBlame.hunks.map { $0.finalLine.start }, stagedStarts)
    XCTAssertTrue(stagedBlame.hunks.first?.finalLine.oid.isZero ?? false)
  }
}
