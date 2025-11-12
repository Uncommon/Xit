import XCTest
@testable import Xit


class StringRepository: CommitStorage
{
  typealias Commit = StringCommit
  typealias RevWalk = NullRevWalk

  let commits: [StringCommit]
  
  init(commits: [StringCommit])
  {
    self.commits = commits
  }
  
  func oid(forSHA sha: SHA) -> GitOID?
  {
    .init(sha: sha)
  }
  
  func commit(forSHA sha: SHA) -> StringCommit?
  {
    commits.first { $0.id.sha == sha }
  }

  func commit(forOID oid: GitOID) -> StringCommit?
  {
    commits.first { $0.id == oid }
  }

  func commit(message: String, amend: Bool) throws {}
  func walker() -> NullRevWalk? { nil }
}


extension Xit.CommitConnection: @retroactive CustomDebugStringConvertible
{
  public var debugDescription: String
  { return "\(childOID.debugDescription)-\(parentOID.debugDescription) \(colorIndex)" }
}


typealias TestCommitHistory = CommitHistory<StringCommit>

class CommitHistoryTest: XCTestCase
{
  var repository: StringRepository? = nil

  func makeHistory(_ commitData: [(GitOID, [GitOID])],
                   heads: [GitOID]? = nil) -> TestCommitHistory?
  {
    let commits = commitData.map {
      (id, parents) -> StringCommit in
      return .init(parentOIDs: parents, id: id)
    }
    
    // Reverse the input to better test the ordering.
    let repository = StringRepository(commits: commits.reversed())
    let history = TestCommitHistory()
    
    self.repository = repository
    history.repository = repository
    
    if let heads = heads {
      let headCommits = heads.compactMap { repository.commit(forOID: $0) }
      guard headCommits.count == heads.count
      else {
        XCTFail("can't get head commits")
        return nil
      }
      
      for commit in headCommits {
        history.process(commit)
      }
      check(history, expectedLength: commitData.count)
    }
    return history
  }
  
  func generateConnections(_ history: TestCommitHistory) -> [[CommitConnection]]
  {
    return history.generateConnections(batchStart: 0,
                                       batchSize: history.entries.count,
                                       starting: []).0
  }
  
  /// Makes sure each commit precedes its parents.
  func check(_ history: TestCommitHistory, expectedLength: Int)
  {
    print("\(history.entries.map({ $0.commit.id.debugDescription }))")
    XCTAssertEqual(history.entries.count, expectedLength)
    for (index, entry) in history.entries.enumerated() {
      for parentOID in entry.commit.parentOIDs {
        guard let parentIndex = history.entries.firstIndex(
            where: { $0.commit.id == parentOID })
        else {
          XCTFail("parent entry not found: \(parentOID)")
          continue
        }
        
        XCTAssert(parentIndex > index,
                  "\(entry.commit.id.sha.shortString) ≮ \(parentOID.sha.shortString)")
      }
    }
  }
  
  /* Simple:
      c-b-a
  */
  func testSimple()
  {
    guard let history = makeHistory([("a", ["b"]), ("b", ["c"]), ("c", [])],
                                    heads: ["a"])
    else { return }
    
    let connections = generateConnections(history)
    
    let aToB = CommitConnection(parentOID: "b", childOID: "a", colorIndex: 0)
    let bToC = CommitConnection(parentOID: "c", childOID: "b", colorIndex: 0)
    
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
    guard let history = makeHistory(
        [("a", ["c"]), ("d", []),
         ("b", ["c"]), ("c", ["d"])],
        heads: ["a", "b"])
    else { return }
    
    let connections = generateConnections(history)
    
    let aToC = CommitConnection(parentOID: "c", childOID: "a", colorIndex: 0)
    let bToC = CommitConnection(parentOID: "c", childOID: "b", colorIndex: 1)
    let cToD = CommitConnection(parentOID: "d", childOID: "c", colorIndex: 0)
    
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
    guard let history = makeHistory(
        [("a", ["c", "b"]), ("b", ["c"]),
         ("c", ["d"]), ("d", [])],
        heads: ["a"])
    else { return }
    
    let connections = generateConnections(history)
    
    let aToC = CommitConnection(parentOID: "c", childOID: "a", colorIndex: 0)
    let aToB = CommitConnection(parentOID: "b", childOID: "a", colorIndex: 1)
    let bToC = CommitConnection(parentOID: "c", childOID: "b", colorIndex: 1)
    let cToD = CommitConnection(parentOID: "d", childOID: "c", colorIndex: 0)
  
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
  func testMerge2() throws
  {
    guard let history = makeHistory(
        [("a", ["d"]), ("b", ["e", "c"]), ("c", ["d"]), ("d", ["aa", "f"]),
         ("e", ["f"]), ("f", ["aa"]), ("aa", [])])
    else { return }
    let repository = try XCTUnwrap(self.repository)

    guard let commitA = repository.commit(forOID: "a"),
          let commitB = repository.commit(forOID: "b")
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
    guard let history = makeHistory(
        [("a", ["c", "b"]), ("b", ["d"]), ("c", ["e", "d"]),
         ("d", ["f"]), ("e", ["f"]), ("f", ["aa"]), ("aa", [])],
        heads: ["a"])
    else { return }
    
    let connections = generateConnections(history)
    
    let aToC = CommitConnection(parentOID: "c", childOID: "a", colorIndex: 0)
    let aToB = CommitConnection(parentOID: "b", childOID: "a", colorIndex: 1)
    let cToE = CommitConnection(parentOID: "e", childOID: "c", colorIndex: 0)
    let cToD = CommitConnection(parentOID: "d", childOID: "c", colorIndex: 2)
    let bToD = CommitConnection(parentOID: "d", childOID: "b", colorIndex: 1)
    let eToF = CommitConnection(parentOID: "f", childOID: "e", colorIndex: 0)
    let dToF = CommitConnection(parentOID: "f", childOID: "d", colorIndex: 1)
    let fToAA = CommitConnection(parentOID: "aa", childOID: "f", colorIndex: 0)
    
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
    guard let history = makeHistory(
        [("a", ["c", "b"]), ("b", ["d", "c"]), ("c", ["e"]),
         ("d", ["f"]), ("e", ["f"]), ("f", ["aa"]), ("aa", [])],
        heads: ["a"])
    else { return }
    
    let connections = generateConnections(history)
    
    let aToC = CommitConnection(parentOID: "c", childOID: "a", colorIndex: 0)
    let aToB = CommitConnection(parentOID: "b", childOID: "a", colorIndex: 1)
    let cToE = CommitConnection(parentOID: "e", childOID: "c", colorIndex: 0)
    let bToC = CommitConnection(parentOID: "c", childOID: "b", colorIndex: 2)
    let bToD = CommitConnection(parentOID: "d", childOID: "b", colorIndex: 1)
    let eToF = CommitConnection(parentOID: "f", childOID: "e", colorIndex: 0)
    let dToF = CommitConnection(parentOID: "f", childOID: "d", colorIndex: 1)
    let fToG = CommitConnection(parentOID: "aa", childOID: "f", colorIndex: 0)
    
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
    guard let _ = makeHistory(
        [("a", ["c", "b"]), ("b", ["d", "e"]), ("c", ["e", "d"]),
         ("d", ["f"]), ("e", ["f"]), ("f", [])],
        heads: ["a"])
    else { return }
  }
  
  /* Cross-merge 4:
      f----e---------a
      \    '--c-,  /
       \   ,-'  \ /
        \-d------b
  */
  func testCrossMerge4()
  {
    guard let _ = makeHistory(
        [("a", ["e", "b"]), ("b", ["d", "c"]), ("c", ["e", "d"]),
         ("d", ["f"]), ("e", ["f"]), ("f", [])],
        heads: ["a"])
    else { return }
  }
  
  /* Cross-merge 5:
      k----h-f---d--b--a
      \j-i-+-\e--+-/  /
           \g---/--c-/
  */
  func testCrossMerge5() throws
  {
    guard let history = makeHistory(
        [("a", ["b", "c"]), ("b", ["d", "e"]), ("c", ["aa"]), ("d", ["f", "aa"]),
         ("e", ["cc", "f"]), ("f", ["bb"]), ("aa", ["bb"]), ("bb", ["ee"]),
         ("cc", ["dd"]), ("dd", ["ee"]), ("ee", [])])
    else { return }
    let repository = try XCTUnwrap(self.repository)

    guard let commitA = repository.commit(forOID: "a"),
          let commitD = repository.commit(forOID: "d"),
          let commitE = repository.commit(forOID: "e"),
          let commitAA = repository.commit(forOID: "aa")
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
    guard let history = makeHistory(
        [("a", ["c"]), ("b", ["d", "c"]), ("c", ["e"]),
         ("d", ["f"]), ("e", ["f"]), ("f", ["aa"]), ("aa", [])],
        heads: ["a", "b"])
    else { return }

    let connections = generateConnections(history)
    
    let aToC = CommitConnection(parentOID: "c", childOID: "a", colorIndex: 0)
    let cToE = CommitConnection(parentOID: "e", childOID: "c", colorIndex: 0)
    let bToC = CommitConnection(parentOID: "c", childOID: "b", colorIndex: 2)
    let bToD = CommitConnection(parentOID: "d", childOID: "b", colorIndex: 1)
    let eToF = CommitConnection(parentOID: "f", childOID: "e", colorIndex: 0)
    let dToF = CommitConnection(parentOID: "f", childOID: "d", colorIndex: 1)
    let fToAA = CommitConnection(parentOID: "aa", childOID: "f", colorIndex: 0)
    
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
    guard let _ = makeHistory(
        [("a", ["d"]), ("b", ["d", "c"]), ("c", ["d"]), ("d", [])],
        heads: ["a", "b"])
    else { return }
  }

  /* Merged fork 3:
      aa-f----/-d-----a
         \-e-/  \--
         \-------c-\-b
  */
  func testMergedFork3() throws
  {
    guard let history = makeHistory(
        [("a", ["d"]), ("b", ["d", "c"]), ("d", ["f", "e"]),
         ("c", ["f"]), ("e", ["f"]), ("f", ["aa"]), ("aa", [])])
    else { return }
    let repository = try XCTUnwrap(self.repository)

    guard let commitA = repository.commit(forOID: "a"),
          let commitB = repository.commit(forOID: "b"),
          let commitE = repository.commit(forOID: "e")
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
         \---d--\b
  */
  func testMergedFork4()
  {
    guard let _ = makeHistory(
        [("a", ["c"]), ("b", ["d", "c"]), ("c", ["f", "e"]), ("d", ["f"]),
         ("e", ["aa"]), ("f", ["aa"]), ("aa", [])],
        heads: ["a", "b"])
    else { return }
  }
  
  /* Merged fork 5:
      e----c---a
      \-d--\-b
  */
  func testMergedFork5()
  {
    guard let _ = makeHistory(
        [("a", ["c"]), ("b", ["d", "c"]), ("c", ["e"]), ("d", ["e"]), ("e", [])],
        heads: ["a", "b"])
    else { return }
  }
  
  /* Disjoint:
      d-c b-a
  */
  func testDisjoint()
  {
    guard let history = makeHistory(
        [("a", ["b"]), ("b", []),
         ("c", ["d"]), ("d", [])],
        heads: ["a", "c"])
    else { return }
    
    let connections = generateConnections(history)
    
    let aToB = CommitConnection(parentOID: "b", childOID: "a", colorIndex: 0)
    let cToD = CommitConnection(parentOID: "d", childOID: "c", colorIndex: 1)
    
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
    guard let history = makeHistory(
        [("a", ["d", "b", "c"]), ("b", ["d"]), ("c", ["d"]), ("d", [])],
        heads: ["a"])
    else { return }
    
    let connections = generateConnections(history)
    
    let aToD = CommitConnection(parentOID: "d", childOID: "a", colorIndex: 0)
    let aToB = CommitConnection(parentOID: "b", childOID: "a", colorIndex: 1)
    let aToC = CommitConnection(parentOID: "c", childOID: "a", colorIndex: 2)
    let bToD = CommitConnection(parentOID: "d", childOID: "b", colorIndex: 1)
    let cToD = CommitConnection(parentOID: "d", childOID: "c", colorIndex: 2)

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
    guard let history = makeHistory(
        [("a", ["c", "b"]), ("b", ["e"]), ("c", ["e", "d"]), ("d", ["e"]),
         ("e", [])],
        heads: ["a"])
    else { return }
    
    let aToC = CommitConnection(parentOID: "c", childOID: "a", colorIndex: 0)
    let aToB = CommitConnection(parentOID: "b", childOID: "a", colorIndex: 1)
    let bToE = CommitConnection(parentOID: "e", childOID: "b", colorIndex: 1)
    let cToE = CommitConnection(parentOID: "e", childOID: "c", colorIndex: 0)
    let cToD = CommitConnection(parentOID: "d", childOID: "c", colorIndex: 2)
    let dToE = CommitConnection(parentOID: "e", childOID: "d", colorIndex: 2)
    
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
    guard let _ = makeHistory(
        [("a", ["b", "d"]), ("b", ["e", "c"]), ("c", ["e"]), ("d", ["f", "e"]),
         ("e", ["aa"]), ("f", ["aa"]), ("aa", [])],
        heads: ["a"])
    else { return }
  }
  
  /* Late merge:
      g----d----b-a
      \-f-/    / /
       \----c-/ /
        \-e----/
  */
  func testLateMerge()
  {
    guard let _ = makeHistory(
        [("a", ["b", "e"]), ("b", ["d", "c"]), ("c", ["aa"]), ("d", ["aa", "f"]),
         ("e", ["aa"]), ("f", ["aa"]), ("aa", [])],
        heads: ["c", "e", "f", "a"]) // out of order
    else { return }
  }
  
  /* Early start:
      d----b-\
      \-c----a
  */
  func testEarlyStart()
  {
    guard let _ = makeHistory(
        [("a", ["b", "c"]), ("b", ["d"]), ("c", ["d"]), ("d", [])],
        heads: ["b", "a"]) // out of order
    else { return }
  }
  
  /* Crossover:
     bb-------e-d------a
      \-aa-f-X----c-b-/
  */
  func testCrossover()
  {
    guard let history = makeHistory(
      [("a", ["d", "b"]), ("b", ["c"]), ("c", ["bb"]), ("d", ["e"]),
       ("e", ["bb", "f"]), ("f", ["aa"]), ("aa", ["bb"]), ("bb", [])],
      heads: ["a", "b", "f"])
    else { return }
    
    history.entries.sort(by: {
      $0.commit.id.sha.rawValue < $1.commit.id.sha.rawValue
    })

    let connections = generateConnections(history)
    
    let aToD = CommitConnection(parentOID: "d", childOID: "a", colorIndex: 0)
    let aToB = CommitConnection(parentOID: "b", childOID: "a", colorIndex: 1)
    let bToC = CommitConnection(parentOID: "c", childOID: "b", colorIndex: 1)
    let cToBB = CommitConnection(parentOID: "bb", childOID: "c", colorIndex: 1)
    let dToE = CommitConnection(parentOID: "e", childOID: "d", colorIndex: 0)
    let eToBB = CommitConnection(parentOID: "bb", childOID: "e", colorIndex: 0)
    let eToF = CommitConnection(parentOID: "f", childOID: "e", colorIndex: 2)
    let fToAA = CommitConnection(parentOID: "aa", childOID: "f", colorIndex: 2)
    let aaToBB = CommitConnection(parentOID: "bb", childOID: "aa", colorIndex: 2)

    XCTAssertEqual(connections[0], [aToD, aToB])
    XCTAssertEqual(connections[1], [aToD, aToB, bToC])
    XCTAssertEqual(connections[2], [aToD, bToC, cToBB])
    XCTAssertEqual(connections[3], [aToD, dToE, cToBB])
    XCTAssertEqual(connections[4], [dToE, eToBB, cToBB, eToF])
    XCTAssertEqual(connections[5], [eToBB, cToBB, eToF, fToAA])
    XCTAssertEqual(connections[6], [eToBB, cToBB, fToAA, aaToBB])
    XCTAssertEqual(connections[7], [eToBB, cToBB, aaToBB])
  }
}
