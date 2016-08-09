import XCTest
@testable import Xit


struct MockCommit: CommitType {
  let SHA: String?
  let parentSHAs: [String]
  
  var message: String? { return nil }
  var commitDate: NSDate { return NSDate() }
  var email: String? { return nil }
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


extension Xit.CommitConnection: CustomDebugStringConvertible {
  var debugDescription: String
  { return "\(childSHA)-\(parentSHA) \(colorIndex)" }
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
    
    history.connectCommits()
    
    let aToB = CommitConnection(parentSHA: "b", childSHA: "a", colorIndex: 0)
    let bToC = CommitConnection(parentSHA: "c", childSHA: "b", colorIndex: 0)
    
    XCTAssertEqual(history.entries[0].connections, [aToB])
    XCTAssertEqual(history.entries[1].connections, [aToB, bToC])
    XCTAssertEqual(history.entries[2].connections, [bToC])
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
    history.process(commitB, afterCommit: nil)
    check(history, expectedLength: 4)
    
    history.connectCommits()
    
    let aToC = CommitConnection(parentSHA: "c", childSHA: "a", colorIndex: 0)
    let bToC = CommitConnection(parentSHA: "c", childSHA: "b", colorIndex: 1)
    let cToD = CommitConnection(parentSHA: "d", childSHA: "c", colorIndex: 0)
    
    XCTAssertEqual(history.entries[0].connections, [aToC])
    XCTAssertEqual(history.entries[1].connections, [aToC, bToC])
    XCTAssertEqual(history.entries[2].connections, [aToC, cToD, bToC])
    XCTAssertEqual(history.entries[3].connections, [cToD])
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
    
    history.connectCommits()
    
    let aToC = CommitConnection(parentSHA: "c", childSHA: "a", colorIndex: 0)
    let aToB = CommitConnection(parentSHA: "b", childSHA: "a", colorIndex: 1)
    let bToC = CommitConnection(parentSHA: "c", childSHA: "b", colorIndex: 1)
    let cToD = CommitConnection(parentSHA: "d", childSHA: "c", colorIndex: 0)
  
    XCTAssertEqual(history.entries[0].connections, [aToC, aToB])
    XCTAssertEqual(history.entries[1].connections, [aToC, aToB, bToC])
    XCTAssertEqual(history.entries[2].connections, [aToC, cToD, bToC])
    XCTAssertEqual(history.entries[3].connections, [cToD])
  }
  
  /* Cross-merge 1:
      g-f-e---c--a
         \-d-/-b/
  */
  func testCrossMerge1()
  {
    let history = makeHistory([
        ("a", ["c", "b"]), ("b", ["d"]), ("c", ["e", "d"]),
        ("d", ["f"]), ("e", ["f"]), ("f", ["g"]), ("g", [])])
    
    
    guard let commitA = history.repository.commit(forSHA: "a")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    check(history, expectedLength: 7)
    
    history.connectCommits()
    
    let aToC = CommitConnection(parentSHA: "c", childSHA: "a", colorIndex: 0)
    let aToB = CommitConnection(parentSHA: "b", childSHA: "a", colorIndex: 1)
    let cToE = CommitConnection(parentSHA: "e", childSHA: "c", colorIndex: 0)
    let cToD = CommitConnection(parentSHA: "d", childSHA: "c", colorIndex: 2)
    let bToD = CommitConnection(parentSHA: "d", childSHA: "b", colorIndex: 1)
    let eToF = CommitConnection(parentSHA: "f", childSHA: "e", colorIndex: 0)
    let dToF = CommitConnection(parentSHA: "f", childSHA: "d", colorIndex: 1)
    let fToG = CommitConnection(parentSHA: "g", childSHA: "f", colorIndex: 0)
    
    XCTAssertEqual(history.entries[0].connections, [aToC, aToB])
    XCTAssertEqual(history.entries[1].connections, [aToC, aToB, bToD])
    XCTAssertEqual(history.entries[2].connections, [aToC, cToE, bToD, cToD])
    XCTAssertEqual(history.entries[3].connections, [cToE, bToD, dToF, cToD])
    XCTAssertEqual(history.entries[4].connections, [cToE, eToF, dToF])
    XCTAssertEqual(history.entries[5].connections, [eToF, fToG, dToF])
    XCTAssertEqual(history.entries[6].connections, [fToG])
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
    
    history.connectCommits()
    
    let aToC = CommitConnection(parentSHA: "c", childSHA: "a", colorIndex: 0)
    let aToB = CommitConnection(parentSHA: "b", childSHA: "a", colorIndex: 1)
    let cToE = CommitConnection(parentSHA: "e", childSHA: "c", colorIndex: 0)
    let bToC = CommitConnection(parentSHA: "c", childSHA: "b", colorIndex: 2)
    let bToD = CommitConnection(parentSHA: "d", childSHA: "b", colorIndex: 1)
    let eToF = CommitConnection(parentSHA: "f", childSHA: "e", colorIndex: 0)
    let dToF = CommitConnection(parentSHA: "f", childSHA: "d", colorIndex: 1)
    let fToG = CommitConnection(parentSHA: "g", childSHA: "f", colorIndex: 0)
    
    XCTAssertEqual(history.entries[0].connections, [aToC, aToB])
    XCTAssertEqual(history.entries[1].connections, [aToC, aToB, bToD, bToC])
    XCTAssertEqual(history.entries[2].connections, [aToC, cToE, bToD, bToC])
    XCTAssertEqual(history.entries[3].connections, [cToE, bToD, dToF])
    XCTAssertEqual(history.entries[4].connections, [cToE, eToF, dToF])
    XCTAssertEqual(history.entries[5].connections, [eToF, fToG, dToF])
    XCTAssertEqual(history.entries[6].connections, [fToG])
  }
  
  /* Cross-merge 4:
      f----e---------a
      \    '--c-,  /
       \   ,-'  \ /
        \-d------b
  */
  func testCrossMerge4()
  {
    let history = makeHistory([
      ("a", ["e", "b"]), ("b", ["d", "c"]), ("c", ["e", "d"]),
      ("d", ["f"]), ("e", ["f"]), ("f", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a")
      else {
        XCTFail("Can't get starting commit")
        return
    }
    
    history.process(commitA, afterCommit: nil)
    check(history, expectedLength: 6)
  }
  
  /* Merged fork:
      g-f-e--c---a
         \-d-\-b
  */
  func testMergedFork()
  {
    let history = makeHistory([
        ("a", ["c"]), ("b", ["d", "c"]), ("c", ["e"]),
        ("d", ["f"]), ("e", ["f"]), ("f", ["g"]), ("g", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a"),
          let commitB = history.repository.commit(forSHA: "b")
    else {
      XCTFail("Can't get starting commits")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    history.process(commitB, afterCommit: nil)
    check(history, expectedLength: 7)
    
    history.connectCommits()
    
    let aToC = CommitConnection(parentSHA: "c", childSHA: "a", colorIndex: 0)
    let cToE = CommitConnection(parentSHA: "e", childSHA: "c", colorIndex: 0)
    let bToC = CommitConnection(parentSHA: "c", childSHA: "b", colorIndex: 2)
    let bToD = CommitConnection(parentSHA: "d", childSHA: "b", colorIndex: 1)
    let eToF = CommitConnection(parentSHA: "f", childSHA: "e", colorIndex: 0)
    let dToF = CommitConnection(parentSHA: "f", childSHA: "d", colorIndex: 1)
    let fToG = CommitConnection(parentSHA: "g", childSHA: "f", colorIndex: 0)
    
    XCTAssertEqual(history.entries[0].connections, [aToC])
    XCTAssertEqual(history.entries[1].connections, [aToC, bToD, bToC])
    XCTAssertEqual(history.entries[2].connections, [aToC, cToE, bToD, bToC])
    XCTAssertEqual(history.entries[3].connections, [cToE, bToD, dToF])
    XCTAssertEqual(history.entries[4].connections, [cToE, eToF, dToF])
    XCTAssertEqual(history.entries[5].connections, [eToF, fToG, dToF])
    XCTAssertEqual(history.entries[6].connections, [fToG])
  }

  /* Merged fork 2:
      d-------a
      \-----b
       \-c-/
  */
  func testMergedFork2()
  {
    let history = makeHistory([
        ("a", ["d"]), ("b", ["d", "c"]), ("c", ["d"]), ("d", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a"),
          let commitB = history.repository.commit(forSHA: "b")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    history.process(commitB, afterCommit: nil)
    check(history, expectedLength: 4)
  }

  /* Merged fork 3:
      g-f----/-d-----a
        \-e-/  \--
        \-------c-\-b
  */
  func testMergedFork3()
  {
    let history = makeHistory([
        ("a", ["d"]), ("b", ["d", "c"]), ("d", ["f", "e"]),
        ("c", ["f"]), ("e", ["f"]), ("f", ["g"]), ("g", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a"),
          let commitB = history.repository.commit(forSHA: "b")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    history.process(commitB, afterCommit: nil)
    check(history, expectedLength: 7)
  }

  /* Merged fork 4:
      g-f----c-----a
      \-+-e-/ \
        \---d-\b
  */
  func testMergedFork4()
  {
    let history = makeHistory([
        ("a", ["c"]), ("b", ["d", "c"]), ("c", ["f", "e"]), ("d", ["f"]),
        ("e", ["g"]), ("f", ["g"]), ("g", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a"),
          let commitB = history.repository.commit(forSHA: "b")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    history.process(commitB, afterCommit: nil)
    check(history, expectedLength: 7)
  }
  
  /* Merged fork 5:
      e----c---a
      \-d--\-b
  */
  func testMergedFork5()
  {
    let history = makeHistory([
        ("a", ["c"]), ("b", ["d", "c"]), ("c", ["e"]), ("d", ["e"]), ("e", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a"),
          let commitB = history.repository.commit(forSHA: "b")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    history.process(commitB, afterCommit: nil)
    check(history, expectedLength: 5)
  }
  
  /* Disjoint:
      d-c b-a
  */
  func testDisjoint()
  {
    let history = makeHistory([
        ("a", ["b"]), ("b", []),
        ("c", ["d"]), ("d", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a"),
          let commitB = history.repository.commit(forSHA: "c")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    history.process(commitB, afterCommit: nil)
    check(history, expectedLength: 4)
    
    history.connectCommits()
    
    let aToB = CommitConnection(parentSHA: "b", childSHA: "a", colorIndex: 0)
    let cToD = CommitConnection(parentSHA: "d", childSHA: "c", colorIndex: 1)
    
    XCTAssertEqual(history.entries[0].connections, [aToB])
    XCTAssertEqual(history.entries[1].connections, [aToB])
    XCTAssertEqual(history.entries[2].connections, [cToD])
    XCTAssertEqual(history.entries[3].connections, [cToD])
  }
  
  /* Multi-merge:
      d------a
      \---b-/
       \-c-/
  */
  func testMultiMerge1()
  {
    let history = makeHistory([
        ("a", ["d", "b", "c"]), ("b", ["d"]), ("c", ["d"]), ("d", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    check(history, expectedLength: 4)
    
    history.connectCommits()
    
    let aToD = CommitConnection(parentSHA: "d", childSHA: "a", colorIndex: 0)
    let aToB = CommitConnection(parentSHA: "b", childSHA: "a", colorIndex: 1)
    let aToC = CommitConnection(parentSHA: "c", childSHA: "a", colorIndex: 2)
    let bToD = CommitConnection(parentSHA: "d", childSHA: "b", colorIndex: 1)
    let cToD = CommitConnection(parentSHA: "d", childSHA: "c", colorIndex: 2)

    XCTAssertEqual(history.entries[0].connections, [aToD, aToB, aToC])
    XCTAssertEqual(history.entries[1].connections, [aToD, aToB, bToD, aToC])
    XCTAssertEqual(history.entries[2].connections, [aToD, bToD, aToC, cToD])
    XCTAssertEqual(history.entries[3].connections, [aToD, bToD, cToD])
  }
  
  /* Multi-merge 2:
      e----c----a
      \-d-/    /
       \----b-/
  */
  func testMultiMerge2()
  {
    let history = makeHistory([
        ("a", ["c", "b"]), ("b", ["e"]), ("c", ["e", "d"]), ("d", ["e"]),
        ("e", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    check(history, expectedLength: 5)
  }
}
