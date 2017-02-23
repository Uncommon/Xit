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
  let blameFile = "elements.txt"
  var blamePath: String!
  
  func commit(lines: [String], message: String)
  {
    let text = lines.joined(separator: "\n")
    
    try! text.write(toFile: blamePath, atomically: true, encoding: .ascii)
    try! repository.stageAllFiles()
    try! repository.commit(withMessage: message, amend: false, outputBlock: nil)
  }
  
  override func setUp()
  {
    super.setUp()
    
    blamePath = repository.repoURL.path.stringByAppendingPathComponent(blameFile)
    commit(lines: elements1, message: "first")
    commit(lines: elements2, message: "second")
    commit(lines: elements3, message: "third")
  }
  
  func testCommitBlame()
  {
    let headSHA = repository.headSHA!
    let headOID = GitOID(sha: headSHA)
    let commitModel = XTCommitChanges(repository: repository,
                                      sha: headSHA)
    let commitBlame = commitModel.blame(for: blameFile, staged: false)!
    let lineStarts = [1, 3, 5, 6]
    let lineCounts = [2, 2, 1, 3]
    
    XCTAssertEqual(commitBlame.hunks.count, 4)
    XCTAssertEqual(commitBlame.hunks.map { $0.finalLineStart }, lineStarts)
    XCTAssertEqual(commitBlame.hunks.map { $0.lineCount }, lineCounts)
    XCTAssertEqual(commitBlame.hunks[2].finalOID, headOID)
  }
  
  func testStagingBlame()
  {
    var elements4 = elements3
    
    elements4[0].append("!!")
    
    let fourthLines = elements4.joined(separator: "\n")
    
    try! fourthLines.write(toFile: blamePath, atomically: true, encoding: .ascii)
    try! repository.stageAllFiles()
    
    var elements5 = elements4
    
    elements5[7].append("##")
    
    let fifthLines = elements5.joined(separator: "\n")
    
    try! fifthLines.write(toFile: blamePath, atomically: true, encoding: .ascii)

    let stagingModel = XTStagingChanges(repository: repository)
    let unstagedBlame = stagingModel.blame(for: blameFile, staged: false)!
    let unstagedStarts = [1, 2, 3, 5, 6, 8]
    
    XCTAssertEqual(unstagedBlame.hunks.count, 6)
    XCTAssertEqual(unstagedBlame.hunks.map { $0.finalLineStart }, unstagedStarts)
    XCTAssertTrue(unstagedBlame.hunks[0].finalOID.isZero)
    XCTAssertTrue(unstagedBlame.hunks.last!.finalOID.isZero)
    
    let stagedBlame = stagingModel.blame(for: blameFile, staged: true)!
    let stagedStarts = [1, 2, 3, 5, 6]
    
    XCTAssertEqual(stagedBlame.hunks.count, 5)
    XCTAssertEqual(stagedBlame.hunks.map { $0.finalLineStart }, stagedStarts)
    XCTAssertTrue(stagedBlame.hunks[0].finalOID.isZero)
  }
}
