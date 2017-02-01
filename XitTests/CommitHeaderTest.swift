import Foundation
@testable import Xit


class TestHeaderGenerator: HeaderGenerator
{
  var repository: RepositoryType!
}

class CommitHeaderTest: XCTestCase
{
  var authorDate, commitDate: Date!
  
  override func setUp()
  {
    authorDate = Date()
    commitDate = Date(timeInterval: 5000, since: authorDate)
  }
  
  func fakeSHA(_ n: Int) -> String
  {
    return String(repeating: "\(n)", count: 40)
  }

  func testHTML()
  {
    let generator = TestHeaderGenerator()
    let oids = [0, 1, 2, 3].map { GTOID(sha: self.fakeSHA($0))! }
    let commit = MockCommit(sha: "blahblah",
                            oid: oids[0],
                            parentOIDs: [oids[1], oids[2], oids[3]])
    
    commit.authorName = "Guy One"
    commit.authorEmail = "guy1@example.com"
    commit.authorDate = authorDate
    commit.committerName = "Guy Two";
    commit.committerEmail = "guy2@example.com";
    commit.commitDate = commitDate
    commit.message = "Example message";
    
    let messages = [1: "Alphabet<>", 2: "Broccoli&", 3: "Cypress"]
    let parents = [1, 2, 3].map {
      (index) -> MockCommit in
      let commit = MockCommit(sha: self.fakeSHA(index), oid: oids[index],
                              parentOIDs: [])
      commit.message = messages[index]
      return commit
    }

    let fakeRepo = MockRepository(commits: [commit, parents[0],
                                            parents[1], parents[2]])
    
    generator.repository = fakeRepo
    
    let html = generator.generateHeaderHTML(commit)
    guard let testBundle = Bundle(identifier: "com.uncommonplace.XitTests"),
          let expectedURL = testBundle.url(forResource: "expected header",
                                            withExtension: "html"),
          let expectedHTMLTemplate = try? String(contentsOf: expectedURL)
    else {
      XCTFail()
      return
    }
    
    let dateFormatter = CommitHeaderViewController.dateFormatter()
    let expectedHTML = String(format: expectedHTMLTemplate,
                              dateFormatter.string(from: authorDate),
                              dateFormatter.string(from: commitDate))
    
    let lines = html.components(separatedBy: "\n")
    let expectedLines = expectedHTML.components(separatedBy: "\n")
    
    XCTAssertEqual(lines.count, expectedLines.count)
    for (index, line) in lines.enumerated() {
      XCTAssertEqual(line, expectedLines[index], "line \(index)")
    }
  }
}
