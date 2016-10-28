import XCTest
@testable import Xit


class MockCommit: NSObject, CommitType
{
  let sha: String?
  let oid: GTOID
  let parentOIDs: [GTOID]
  
  var message: String? { return nil }
  var commitDate: Date { return Date() }
  var email: String? { return nil }
  
  init(sha: String?, oid: GTOID, parentOIDs: [GTOID])
  {
    self.sha = sha
    self.oid = oid
    self.parentOIDs = parentOIDs
  }
}

func == (a: MockCommit, b: MockCommit) -> Bool
{
  return a.oid == b.oid
}


extension GTOID
{
  convenience init(oid: String)
  {
    let padded = (oid as NSString).padding(toLength: 40, withPad: "0", startingAt: 0)
    
    self.init(sha: padded)!
  }
}


class MockRepository: NSObject, RepositoryType
{
  let commits: [MockCommit]
  
  init(commits: [MockCommit])
  {
    self.commits = commits
  }
  
  func commit(forSHA sha: String) -> CommitType?
  {
    for commit in commits {
      if commit.sha == sha {
        return commit
      }
    }
    return nil
  }

  func commit(forOID oid: GTOID) -> CommitType?
  {
    for commit in commits {
      if commit.oid == oid {
        return commit
      }
    }
    return nil
  }
}


extension Xit.CommitConnection: CustomDebugStringConvertible
{
  public var debugDescription: String
  { return "\(childOID.sha)-\(parentOID.sha) \(colorIndex)" }
}


extension Xit.CommitConnection
{
  init(parentSHA: String, childSHA: String, colorIndex: UInt)
  {
    self.init(parentOID: GTOID(oid: parentSHA),
              childOID: GTOID(oid: childSHA),
              colorIndex: colorIndex)
  }
}


class XTCommitHistoryTest: XCTestCase
{
  func makeHistory(_ commitData: [(String, [String])]) -> XTCommitHistory
  {
    let commits = commitData.map({ (sha, parents) in
        MockCommit(sha: sha,
                   oid: GTOID(oid: sha),
                   parentOIDs: parents.map { GTOID(oid: $0) }) })
    // Reverse the input to better test the ordering.
    let repository = MockRepository(commits: commits.reversed())
    let history = XTCommitHistory()
    
    history.repository = repository
    return history
  }
  
  /// Makes sure each commit preceds its parents.
  func check(_ history: XTCommitHistory, expectedLength: Int)
  {
    print("\(history.entries.flatMap({ $0.commit.sha }))")
    XCTAssert(history.entries.count == expectedLength)
    for (index, entry) in history.entries.enumerated() {
      for parentOID in entry.commit.parentOIDs {
        let parentIndex = history.entries.index(
            where: { $0.commit.oid == parentOID })
        
        XCTAssert(parentIndex! > index, "\(entry.commit.sha!.firstSix()) !< \(parentOID.sha.firstSix())")
      }
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
  
  /* Merge 2:
      aa-----d----a
      \-f---/\-c\
        \-e------b
  */
  func testMerge2()
  {
    let history = makeHistory([
        ("a", ["d"]), ("b", ["e", "c"]), ("c", ["d"]), ("d", ["aa", "f"]),
        ("e", ["f"]), ("f", ["aa"]), ("aa", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a"),
          let commitB = history.repository.commit(forSHA: "b")
      else {
        XCTFail("Can't get starting commit")
        return
    }
    
    history.process(commitA, afterCommit: nil)
    check(history, expectedLength: 4)
    history.process(commitB, afterCommit: nil)
    check(history, expectedLength: 7)
  }
  
  /* Cross-merge 1:
      aa-f--------e-/-c-a
         \     /--/   /
          \-d-/-b----/
  */
  func testCrossMerge1()
  {
    let history = makeHistory([
        ("a", ["c", "b"]), ("b", ["d"]), ("c", ["e", "d"]),
        ("d", ["f"]), ("e", ["f"]), ("f", ["aa"]), ("aa", [])])
    
    
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
    let fToAA = CommitConnection(parentSHA: "aa", childSHA: "f", colorIndex: 0)
    
    // Order is ["a", "c", "e", "b", "d", "f", "aa"]
    XCTAssertEqual(history.entries[0].connections, [aToC, aToB])
    XCTAssertEqual(history.entries[1].connections, [aToC, cToE, aToB, cToD])
    XCTAssertEqual(history.entries[2].connections, [cToE, eToF, aToB, cToD])
    XCTAssertEqual(history.entries[3].connections, [eToF, aToB, bToD, cToD])
    XCTAssertEqual(history.entries[4].connections, [eToF, bToD, dToF, cToD])
    XCTAssertEqual(history.entries[5].connections, [eToF, fToAA, dToF])
    XCTAssertEqual(history.entries[6].connections, [fToAA])
  }
  
  /* Cross-merge 2:
      aa-f---e-c----a
         \-d--\-b-/
  */
  func testCrossMerge2()
  {
    let history = makeHistory([
        ("a", ["c", "b"]), ("b", ["d", "c"]), ("c", ["e"]),
        ("d", ["f"]), ("e", ["f"]), ("f", ["aa"]), ("aa", [])])
    
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
    let fToG = CommitConnection(parentSHA: "aa", childSHA: "f", colorIndex: 0)
    
    // Order is ["a", "b", "c", "e", "d", "f", "aa"]
    XCTAssertEqual(history.entries[0].connections, [aToC, aToB])
    XCTAssertEqual(history.entries[1].connections, [aToC, aToB, bToD, bToC])
    XCTAssertEqual(history.entries[2].connections, [aToC, cToE, bToD, bToC])
    XCTAssertEqual(history.entries[3].connections, [cToE, eToF, bToD])
    XCTAssertEqual(history.entries[4].connections, [eToF, bToD, dToF])
    XCTAssertEqual(history.entries[5].connections, [eToF, fToG, dToF])
    XCTAssertEqual(history.entries[6].connections, [fToG])
  }
  
  /* Cross-merge 3:
      f---e-/c---a
      \   X     /
       \-d-\-b-/
  */
  func testCrossMerge3()
  {
    let history = makeHistory([
        ("a", ["c", "b"]), ("b", ["d", "e"]), ("c", ["e", "d"]),
        ("d", ["f"]), ("e", ["f"]), ("f", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    check(history, expectedLength: 6)
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
  
  /* Cross-merge 5:
      k----h-f---d--b--a
      \j-i-+-\e--+-/  /
           \g---/--c-/
  */
  func testCrossMerge5()
  {
    let history = makeHistory([
        ("a", ["b", "c"]), ("b", ["d", "e"]), ("c", ["aa"]), ("d", ["f", "aa"]),
        ("e", ["cc", "f"]), ("f", ["bb"]), ("aa", ["bb"]), ("bb", ["ee"]),
        ("cc", ["dd"]), ("dd", ["ee"]), ("ee", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a"),
          let commitD = history.repository.commit(forSHA: "d"),
          let commitE = history.repository.commit(forSHA: "e"),
          let commitAA = history.repository.commit(forSHA: "aa")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    check(history, expectedLength: 11)
    
    history.reset()
    history.process(commitD)
    history.process(commitE)
    history.process(commitAA)
    history.process(commitA)
    check(history, expectedLength: 11)
  }
  
  /* Merged fork:
      g-f---e-c---a
         \-d--\-b
  */
  func testMergedFork()
  {
    let history = makeHistory([
        ("a", ["c"]), ("b", ["d", "c"]), ("c", ["e"]),
        ("d", ["f"]), ("e", ["f"]), ("f", ["aa"]), ("aa", [])])
    
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
    let fToAA = CommitConnection(parentSHA: "aa", childSHA: "f", colorIndex: 0)
    
    // Order is ["a", "b", "c", "e", "d", "f", "aa"]
    XCTAssertEqual(history.entries[0].connections, [aToC])
    XCTAssertEqual(history.entries[1].connections, [aToC, bToD, bToC])
    XCTAssertEqual(history.entries[2].connections, [aToC, cToE, bToD, bToC])
    XCTAssertEqual(history.entries[3].connections, [cToE, eToF, bToD])
    XCTAssertEqual(history.entries[4].connections, [eToF, bToD, dToF])
    XCTAssertEqual(history.entries[5].connections, [eToF, fToAA, dToF])
    XCTAssertEqual(history.entries[6].connections, [fToAA])
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
      aa-f----/-d-----a
         \-e-/  \--
         \-------c-\-b
  */
  func testMergedFork3()
  {
    let history = makeHistory([
        ("a", ["d"]), ("b", ["d", "c"]), ("d", ["f", "e"]),
        ("c", ["f"]), ("e", ["f"]), ("f", ["aa"]), ("aa", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a"),
          let commitB = history.repository.commit(forSHA: "b"),
          let commitE = history.repository.commit(forSHA: "e")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    history.process(commitB, afterCommit: nil)
    check(history, expectedLength: 7)
    
    history.reset()
    history.process(commitE)
    history.process(commitA)
    history.process(commitB)
  }

  /* Merged fork 4:
      aa-f----c-----a
       \-+-e-/ \
         \---d-\b
  */
  func testMergedFork4()
  {
    let history = makeHistory([
        ("a", ["c"]), ("b", ["d", "c"]), ("c", ["f", "e"]), ("d", ["f"]),
        ("e", ["aa"]), ("f", ["aa"]), ("aa", [])])
    
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
          let commitC = history.repository.commit(forSHA: "c")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitA, afterCommit: nil)
    history.process(commitC, afterCommit: nil)
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
      \-b---/
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

    // Order is ["a", "c", "b", "d"]
    XCTAssertEqual(history.entries[0].connections, [aToD, aToB, aToC])
    XCTAssertEqual(history.entries[1].connections, [aToD, aToB, aToC, cToD])
    XCTAssertEqual(history.entries[2].connections, [aToD, aToB, bToD, cToD])
    XCTAssertEqual(history.entries[3].connections, [aToD, bToD, cToD])
  }
  
  /* Multi-merge 2:
      e----c--a
      |\b--+-/
      \--d-/
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

    let aToC = CommitConnection(parentSHA: "c", childSHA: "a", colorIndex: 0)
    let aToB = CommitConnection(parentSHA: "b", childSHA: "a", colorIndex: 1)
    let bToE = CommitConnection(parentSHA: "e", childSHA: "b", colorIndex: 1)
    let cToE = CommitConnection(parentSHA: "e", childSHA: "c", colorIndex: 0)
    let cToD = CommitConnection(parentSHA: "d", childSHA: "c", colorIndex: 2)
    let dToE = CommitConnection(parentSHA: "e", childSHA: "d", colorIndex: 2)
    
    history.connectCommits()
    
    // Order is ["a", "c", "d", "b", "e"]
    XCTAssertEqual(history.entries[0].connections, [aToC, aToB])
    XCTAssertEqual(history.entries[1].connections, [aToC, cToE, aToB, cToD])
    XCTAssertEqual(history.entries[2].connections, [cToE, aToB, cToD, dToE])
    XCTAssertEqual(history.entries[3].connections, [cToE, aToB, bToE, dToE])
    XCTAssertEqual(history.entries[4].connections, [cToE, bToE, dToE])
  }
  
  /* Double branch:
      g---e\-\-----b--a
      \-f---d-+----+-/
              \-c-/
  */
  func testDoubleBranch()
  {
    let history = makeHistory([
        ("a", ["b", "d"]), ("b", ["e", "c"]), ("c", ["e"]), ("d", ["f", "e"]),
        ("e", ["aa"]), ("f", ["aa"]), ("aa", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a")
      else {
        XCTFail("Can't get starting commit")
        return
    }
    
    history.process(commitA, afterCommit: nil)
    check(history, expectedLength: 7)
  }
  
  /* Late merge:
      g----d----b-a
      \-f-/    / /
       \----c-/ /
        \-e----/
  */
  func testLateMerge()
  {
    let history = makeHistory([
        ("a", ["b", "e"]), ("b", ["d", "c"]), ("c", ["aa"]), ("d", ["aa", "f"]),
        ("e", ["aa"]), ("f", ["aa"]), ("aa", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a"),
          let commitC = history.repository.commit(forSHA: "c"),
          let commitE = history.repository.commit(forSHA: "e"),
          let commitF = history.repository.commit(forSHA: "f")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitC, afterCommit: nil)
    history.process(commitE, afterCommit: nil)
    history.process(commitF, afterCommit: nil)
    history.process(commitA, afterCommit: nil)
    check(history, expectedLength: 7)
  }
  
  /* Early start:
      d----b-\
      \-c----a
  */
  func testEarlyStart()
  {
    let history = makeHistory([
        ("a", ["b", "c"]), ("b", ["d"]), ("c", ["d"]), ("d", [])])
    
    guard let commitA = history.repository.commit(forSHA: "a"),
          let commitB = history.repository.commit(forSHA: "b")
    else {
      XCTFail("Can't get starting commit")
      return
    }
    
    history.process(commitB, afterCommit: nil)
    history.process(commitA, afterCommit: nil)
    check(history, expectedLength: 4)
  }
}
