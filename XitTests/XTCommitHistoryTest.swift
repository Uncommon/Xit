import XCTest
@testable import Xit


class GenericCommit: CommitType
{
  let sha: String?
  let oid: OID
  let parentOIDs: [OID]
  
  var message: String? = nil
  var authorName: String? = nil
  var authorEmail: String? = nil
  var authorDate: Date? = nil
  var committerName: String? = nil
  var committerEmail: String? = nil
  var commitDate = Date()
  var email: String? = nil
  
  init(sha: String?, oid: OID, parentOIDs: [OID])
  {
    self.sha = sha
    self.oid = oid
    self.parentOIDs = parentOIDs
  }
  
  init(sha: String, parentOIDs: [OID])
  {
    self.sha = sha
    self.oid = §sha
    self.parentOIDs = parentOIDs
  }
}

func == (a: GenericCommit, b: GenericCommit) -> Bool
{
  return a.oid.equals(b.oid)
}


extension GTOID
{
  convenience init(oid: String)
  {
    let padded = (oid as NSString).padding(toLength: 40, withPad: "0",
                                           startingAt: 0)
    
    self.init(sha: padded)!
  }
}


class GenericRepository<Commit: CommitType, ID: OID & Hashable>: CommitStorage
{
  typealias C = Commit

  let commits: [Commit]
  
  init(commits: [Commit])
  {
    self.commits = commits
  }
  
  func commit(forSHA sha: String) -> Commit?
  {
    for commit in commits {
      if commit.sha == sha {
        return commit
      }
    }
    return nil
  }

  func commit(forOID oid: ID) -> Commit?
  {
    for commit in commits {
      if commit.oid.equals(oid) {
        return commit
      }
    }
    return nil
  }
}

typealias MockRepository = GenericRepository<GenericCommit, GitOID>
typealias StringRepository = GenericRepository<GenericCommit, StringOID>


extension Xit.CommitConnection: CustomDebugStringConvertible
{
  public var debugDescription: String
  { return "\(childOID.sha)-\(parentOID.sha) \(colorIndex)" }
}


typealias TestCommitHistory = XTCommitHistory<StringRepository>

class XTCommitHistoryTest: XCTestCase
{
  typealias StringConnection = CommitConnection<StringOID>

  func makeHistory(_ commitData: [(String, [String])]) -> TestCommitHistory
  {
    let commits = commitData.map({
      (arg) -> GenericCommit in
      let (sha, parents) = arg
      return GenericCommit(sha: sha,
                           parentOIDs: parents.map { §$0 })
    })
    // Reverse the input to better test the ordering.
    let repository = StringRepository(commits: commits.reversed())
    let history = TestCommitHistory()
    
    history.repository = repository
    return history
  }
  
  func generateConnections(_ history: TestCommitHistory) -> [[StringConnection]]
  {
    return history.generateConnections(batchStart: 0,
                                       batchSize: history.entries.count,
                                       starting: [])
  }
  
  /// Makes sure each commit preceds its parents.
  func check(_ history: TestCommitHistory, expectedLength: Int)
  {
    print("\(history.entries.flatMap({ $0.commit.sha }))")
    XCTAssert(history.entries.count == expectedLength)
    for (index, entry) in history.entries.enumerated() {
      for parentOID in entry.commit.parentOIDs {
        let parentIndex = history.entries.index(
            where: { $0.commit.oid.equals(parentOID) })
        
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
    
    let connections = generateConnections(history)
    
    let aToB = CommitConnection(parentOID: §"b", childOID: §"a", colorIndex: 0)
    let bToC = CommitConnection(parentOID: §"c", childOID: §"b", colorIndex: 0)
    
    XCTAssertEqual(connections[0], [aToB])
    XCTAssertEqual(connections[1], [aToB, bToC])
    XCTAssertEqual(connections[2], [bToC])
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
    
    let connections = generateConnections(history)
    
    let aToC = CommitConnection(parentOID: §"c", childOID: §"a", colorIndex: 0)
    let bToC = CommitConnection(parentOID: §"c", childOID: §"b", colorIndex: 1)
    let cToD = CommitConnection(parentOID: §"d", childOID: §"c", colorIndex: 0)
    
    XCTAssertEqual(connections[0], [aToC])
    XCTAssertEqual(connections[1], [aToC, bToC])
    XCTAssertEqual(connections[2], [aToC, cToD, bToC])
    XCTAssertEqual(connections[3], [cToD])
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
    
    let connections = generateConnections(history)
    
    let aToC = CommitConnection(parentOID: §"c", childOID: §"a", colorIndex: 0)
    let aToB = CommitConnection(parentOID: §"b", childOID: §"a", colorIndex: 1)
    let bToC = CommitConnection(parentOID: §"c", childOID: §"b", colorIndex: 1)
    let cToD = CommitConnection(parentOID: §"d", childOID: §"c", colorIndex: 0)
  
    XCTAssertEqual(connections[0], [aToC, aToB])
    XCTAssertEqual(connections[1], [aToC, aToB, bToC])
    XCTAssertEqual(connections[2], [aToC, cToD, bToC])
    XCTAssertEqual(connections[3], [cToD])
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
    
    let connections = generateConnections(history)
    
    let aToC = CommitConnection(parentOID: §"c", childOID: §"a", colorIndex: 0)
    let aToB = CommitConnection(parentOID: §"b", childOID: §"a", colorIndex: 1)
    let cToE = CommitConnection(parentOID: §"e", childOID: §"c", colorIndex: 0)
    let cToD = CommitConnection(parentOID: §"d", childOID: §"c", colorIndex: 2)
    let bToD = CommitConnection(parentOID: §"d", childOID: §"b", colorIndex: 1)
    let eToF = CommitConnection(parentOID: §"f", childOID: §"e", colorIndex: 0)
    let dToF = CommitConnection(parentOID: §"f", childOID: §"d", colorIndex: 1)
    let fToAA = CommitConnection(parentOID: §"aa", childOID: §"f", colorIndex: 0)
    
    // Order is ["a", "c", "e", "b", "d", "f", "aa"]
    XCTAssertEqual(connections[0], [aToC, aToB])
    XCTAssertEqual(connections[1], [aToC, cToE, aToB, cToD])
    XCTAssertEqual(connections[2], [cToE, eToF, aToB, cToD])
    XCTAssertEqual(connections[3], [eToF, aToB, bToD, cToD])
    XCTAssertEqual(connections[4], [eToF, bToD, dToF, cToD])
    XCTAssertEqual(connections[5], [eToF, fToAA, dToF])
    XCTAssertEqual(connections[6], [fToAA])
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
    
    let connections = generateConnections(history)
    
    let aToC = CommitConnection(parentOID: §"c", childOID: §"a", colorIndex: 0)
    let aToB = CommitConnection(parentOID: §"b", childOID: §"a", colorIndex: 1)
    let cToE = CommitConnection(parentOID: §"e", childOID: §"c", colorIndex: 0)
    let bToC = CommitConnection(parentOID: §"c", childOID: §"b", colorIndex: 2)
    let bToD = CommitConnection(parentOID: §"d", childOID: §"b", colorIndex: 1)
    let eToF = CommitConnection(parentOID: §"f", childOID: §"e", colorIndex: 0)
    let dToF = CommitConnection(parentOID: §"f", childOID: §"d", colorIndex: 1)
    let fToG = CommitConnection(parentOID: §"aa", childOID: §"f", colorIndex: 0)
    
    // Order is ["a", "b", "c", "e", "d", "f", "aa"]
    XCTAssertEqual(connections[0], [aToC, aToB])
    XCTAssertEqual(connections[1], [aToC, aToB, bToD, bToC])
    XCTAssertEqual(connections[2], [aToC, cToE, bToD, bToC])
    XCTAssertEqual(connections[3], [cToE, eToF, bToD])
    XCTAssertEqual(connections[4], [eToF, bToD, dToF])
    XCTAssertEqual(connections[5], [eToF, fToG, dToF])
    XCTAssertEqual(connections[6], [fToG])
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
    
    let connections = generateConnections(history)
    
    let aToC = CommitConnection(parentOID: §"c", childOID: §"a", colorIndex: 0)
    let cToE = CommitConnection(parentOID: §"e", childOID: §"c", colorIndex: 0)
    let bToC = CommitConnection(parentOID: §"c", childOID: §"b", colorIndex: 2)
    let bToD = CommitConnection(parentOID: §"d", childOID: §"b", colorIndex: 1)
    let eToF = CommitConnection(parentOID: §"f", childOID: §"e", colorIndex: 0)
    let dToF = CommitConnection(parentOID: §"f", childOID: §"d", colorIndex: 1)
    let fToAA = CommitConnection(parentOID: §"aa", childOID: §"f", colorIndex: 0)
    
    // Order is ["a", "b", "c", "e", "d", "f", "aa"]
    XCTAssertEqual(connections[0], [aToC])
    XCTAssertEqual(connections[1], [aToC, bToD, bToC])
    XCTAssertEqual(connections[2], [aToC, cToE, bToD, bToC])
    XCTAssertEqual(connections[3], [cToE, eToF, bToD])
    XCTAssertEqual(connections[4], [eToF, bToD, dToF])
    XCTAssertEqual(connections[5], [eToF, fToAA, dToF])
    XCTAssertEqual(connections[6], [fToAA])
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
    
    let connections = generateConnections(history)
    
    let aToB = CommitConnection(parentOID: §"b", childOID: §"a", colorIndex: 0)
    let cToD = CommitConnection(parentOID: §"d", childOID: §"c", colorIndex: 1)
    
    XCTAssertEqual(connections[0], [aToB])
    XCTAssertEqual(connections[1], [aToB])
    XCTAssertEqual(connections[2], [cToD])
    XCTAssertEqual(connections[3], [cToD])
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
    
    let connections = generateConnections(history)
    
    let aToD = CommitConnection(parentOID: §"d", childOID: §"a", colorIndex: 0)
    let aToB = CommitConnection(parentOID: §"b", childOID: §"a", colorIndex: 1)
    let aToC = CommitConnection(parentOID: §"c", childOID: §"a", colorIndex: 2)
    let bToD = CommitConnection(parentOID: §"d", childOID: §"b", colorIndex: 1)
    let cToD = CommitConnection(parentOID: §"d", childOID: §"c", colorIndex: 2)

    // Order is ["a", "c", "b", "d"]
    XCTAssertEqual(connections[0], [aToD, aToB, aToC])
    XCTAssertEqual(connections[1], [aToD, aToB, aToC, cToD])
    XCTAssertEqual(connections[2], [aToD, aToB, bToD, cToD])
    XCTAssertEqual(connections[3], [aToD, bToD, cToD])
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

    let aToC = CommitConnection(parentOID: §"c", childOID: §"a", colorIndex: 0)
    let aToB = CommitConnection(parentOID: §"b", childOID: §"a", colorIndex: 1)
    let bToE = CommitConnection(parentOID: §"e", childOID: §"b", colorIndex: 1)
    let cToE = CommitConnection(parentOID: §"e", childOID: §"c", colorIndex: 0)
    let cToD = CommitConnection(parentOID: §"d", childOID: §"c", colorIndex: 2)
    let dToE = CommitConnection(parentOID: §"e", childOID: §"d", colorIndex: 2)
    
    let connections = generateConnections(history)
    
    // Order is ["a", "c", "d", "b", "e"]
    XCTAssertEqual(connections[0], [aToC, aToB])
    XCTAssertEqual(connections[1], [aToC, cToE, aToB, cToD])
    XCTAssertEqual(connections[2], [cToE, aToB, cToD, dToE])
    XCTAssertEqual(connections[3], [cToE, aToB, bToE, dToE])
    XCTAssertEqual(connections[4], [cToE, bToE, dToE])
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
