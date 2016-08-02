import XCTest
@testable import Xit


struct MockCommit: CommitType {
  let SHA: String?
  let parentSHAs: [String]
}


class MockRepository: RepositoryType {
  let commits: [MockCommit]
  
  init(commits: [MockCommit])
  {
    self.commits = commits
  }
  
  func commit(forSHA sha: String) -> CommitType?
  {
    for commit in commits {
      if commit.SHA == sha {
        return commit
      }
    }
    return nil
  }
}


class XTCommitHistoryTest: XCTestCase {
  
  func makeHistory(commitData: [(String, [String])]) -> XTCommitHistory
  {
    let commits = commitData.map({ (sha, parents) in
        MockCommit(SHA: sha, parentSHAs: parents) })
    // Reverse the input to better test the ordering.
    let repository = MockRepository(commits: commits.reverse())
    
    return XTCommitHistory(repository: repository)
  }
  
  func check(history: XTCommitHistory, expectedLength: Int)
  {
    let letters = "abcdefghijklmnopqrstuvwxyz"
    
    print("\(history.entries.flatMap({ $0.commit.SHA }))")
    XCTAssertEqual(history.entries.count, expectedLength)
    for (index, sha) in history.entries.flatMap({ $0.commit.SHA }).enumerate() {
      let letterIndex = letters.startIndex.advancedBy(index)
      
      XCTAssertEqual(sha, letters.substringWithRange(letterIndex...letterIndex))
    }
  }
  
  /* Simple:
      c-b-a
  */
  func testSimple()
  {
    let history = makeHistory([("a", ["b"]), ("b", ["c"]), ("c", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    check(history, expectedLength: 3)
  }
  
  /* Fork:
      d-c---a
         \-b
  */
  func testFork()
  {
    let history = makeHistory([
        ("a", ["c"]), ("d", []),
        ("b", ["c"]), ("c", ["d"])])
    
    guard let commitA = history.repository.commit(forSHA: "a"),
          let commitB = history.repository.commit(forSHA: "b")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    history.process(commitB, afterCommit: commitA)
    check(history, expectedLength: 4)
  }
  
  /* Merge:
      d-c-----a
         \-b-/
  */
  func testMerge()
  {
    let history = makeHistory([
        ("a", ["c", "b"]), ("b", ["c"]),
        ("c", ["d"]), ("d", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    check(history, expectedLength: 4)
  }
  
  /* Cross-merge 1:
      g-f-e---c--a
         \-d-/-b/
  */
  func testCrossMerge1()
  {
    let history = makeHistory([
        ("a", ["c", "b"]), ("b", ["c"]), ("c", ["e", "d"]),
        ("d", ["f"]), ("e", ["f"]), ("f", ["g"]), ("g", [])])
    
    
    guard let commitA = history.repository.commit(forSHA: "a")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    check(history, expectedLength: 7)
  }
  
  /* Cross-merge 2:
      g-f-e--c----a
         \-d-\-b-/
  */
  func testCrossMerge2()
  {
    let history = makeHistory([
      ("a", ["c", "b"]), ("b", ["d", "c"]), ("c", ["e"]),
      ("d", ["f"]), ("e", ["f"]), ("f", ["g"]), ("g", [])])
    
    
    guard let commitA = history.repository.commit(forSHA: "a")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    check(history, expectedLength: 7)
  }
}
