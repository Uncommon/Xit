import XCTest
@testable import XitGit

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

    let unstagedBlame = try XCTUnwrap(repository.blame(for: TestFileName.blame.rawValue,
                                                       from: nil,
                                                       to: nil),
                                      "can't get unstaged blame")
    let unstagedStarts = [1, 2, 3, 5, 6, 8]
    
    XCTAssertEqual(unstagedBlame.hunks.count, 6)
    XCTAssertEqual(unstagedBlame.hunks.map { $0.finalLine.start }, unstagedStarts)
    XCTAssertTrue(unstagedBlame.hunks.first?.finalLine.oid.isZero ?? false)
    XCTAssertTrue(unstagedBlame.hunks.last?.finalLine.oid.isZero ?? false)
    
    let stagedData = try XCTUnwrap(repository.contentsOfStagedFile(path: TestFileName.blame.rawValue))
    let stagedBlame = try XCTUnwrap(repository.blame(for: TestFileName.blame.rawValue,
                                                     data: stagedData,
                                                     to: nil),
                                    "can't get staged blame")
    let stagedStarts = [1, 2, 3, 5, 6]
    
    XCTAssertEqual(stagedBlame.hunks.count, 5)
    XCTAssertEqual(stagedBlame.hunks.map { $0.finalLine.start }, stagedStarts)
    XCTAssertTrue(stagedBlame.hunks.first?.finalLine.oid.isZero ?? false)
  }
}
