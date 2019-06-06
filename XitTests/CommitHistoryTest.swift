import XCTest
@testable import Xit


class GenericCommit: Commit
{
  let sha: String?
  let oid: OID
  let parentOIDs: [OID]
  
  var message: String? = nil
  var authorSig: Signature? = nil
  var committerSig: Signature? = nil
  var email: String? = nil
  var tree: Tree? = nil
  
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


class GenericRepository<ID: OID & Hashable>: CommitStorage
{
  let commits: [Commit]
  
  init(commits: [Commit])
  {
    self.commits = commits
  }
  
  func oid(forSHA sha: String) -> OID?
  {
    return StringOID(sha: sha)
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

  func commit(forOID oid: OID) -> Commit?
  {
    for commit in commits {
      if commit.oid.equals(oid) {
        return commit
      }
    }
    return nil
  }
  
  func commit(message: String, amend: Bool) throws {}
  
  func walker() -> RevWalk?
  {
    return nil
  }
}

typealias MockRepository = GenericRepository<GitOID>
typealias StringRepository = GenericRepository<StringOID>


extension Xit.CommitConnection: CustomDebugStringConvertible
{
  public var debugDescription: String
  { return "\(childOID.sha)-\(parentOID.sha) \(colorIndex)" }
}


typealias TestCommitHistory = CommitHistory<StringOID>

class CommitHistoryTest: XCTestCase
{
  typealias StringConnection = CommitConnection<StringOID>
  
  var repository: StringRepository? = nil

  func makeHistory(_ commitData: [(String, [String])],
                   heads: [String]? = nil) -> TestCommitHistory?
  {
    let commits = commitData.map({
      (arg) -> GenericCommit in
      let (sha, parents) = arg
      return GenericCommit(sha: sha,
                           parentOIDs: parents.map { §$0 })
    })
    
    // Reverse the input to better test the ordering.
    repository = StringRepository(commits: commits.reversed())
    
    let history = TestCommitHistory()
    
    history.repository = repository
    
    if let heads = heads {
      let headCommits = heads.compactMap { history.repository.commit(forSHA: $0) }
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
  
  func generateConnections(_ history: TestCommitHistory) -> [[StringConnection]]
  {
    return history.generateConnections(batchStart: 0,
                                       batchSize: history.entries.count,
                                       starting: []).0
  }
  
  /// Makes sure each commit precedes its parents.
  func check(_ history: TestCommitHistory, expectedLength: Int)
  {
    print("\(history.entries.flatMap({ $0.commit.sha }))")
    XCTAssertEqual(history.entries.count, expectedLength)
    for (index, entry) in history.entries.enumerated() {
      for parentOID in entry.commit.parentOIDs {
        let parentIndex = history.entries.firstIndex(
            where: { $0.commit.oid.equals(parentOID) })
        
        XCTAssert(parentIndex! > index,
                  "\(entry.commit.sha.firstSix()) ≮ \(parentOID.sha.firstSix())")
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
    guard let history = makeHistory(
        [("a", ["c"]), ("d", []),
         ("b", ["c"]), ("c", ["d"])],
        heads: ["a", "b"])
    else { return }
    
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
    guard let history = makeHistory(
        [("a", ["c", "b"]), ("b", ["c"]),
         ("c", ["d"]), ("d", [])],
        heads: ["a"])
    else { return }
    
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
    guard let history = makeHistory(
        [("a", ["d"]), ("b", ["e", "c"]), ("c", ["d"]), ("d", ["aa", "f"]),
         ("e", ["f"]), ("f", ["aa"]), ("aa", [])])
    else { return }
    
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
    guard let history = makeHistory(
        [("a", ["c", "b"]), ("b", ["d"]), ("c", ["e", "d"]),
         ("d", ["f"]), ("e", ["f"]), ("f", ["aa"]), ("aa", [])],
        heads: ["a"])
    else { return }
    
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
    guard let history = makeHistory(
        [("a", ["c", "b"]), ("b", ["d", "c"]), ("c", ["e"]),
         ("d", ["f"]), ("e", ["f"]), ("f", ["aa"]), ("aa", [])],
        heads: ["a"])
    else { return }
    
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
  func testCrossMerge5()
  {
    guard let history = makeHistory(
        [("a", ["b", "c"]), ("b", ["d", "e"]), ("c", ["aa"]), ("d", ["f", "aa"]),
         ("e", ["cc", "f"]), ("f", ["bb"]), ("aa", ["bb"]), ("bb", ["ee"]),
         ("cc", ["dd"]), ("dd", ["ee"]), ("ee", [])])
    else { return }
    
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
    guard let history = makeHistory(
        [("a", ["c"]), ("b", ["d", "c"]), ("c", ["e"]),
         ("d", ["f"]), ("e", ["f"]), ("f", ["aa"]), ("aa", [])],
        heads: ["a", "b"])
    else { return }

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
  func testMergedFork3()
  {
    guard let history = makeHistory(
        [("a", ["d"]), ("b", ["d", "c"]), ("d", ["f", "e"]),
         ("c", ["f"]), ("e", ["f"]), ("f", ["aa"]), ("aa", [])])
    else { return }
    
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
    guard let history = makeHistory(
        [("a", ["d", "b", "c"]), ("b", ["d"]), ("c", ["d"]), ("d", [])],
        heads: ["a"])
    else { return }
    
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
    guard let history = makeHistory(
        [("a", ["c", "b"]), ("b", ["e"]), ("c", ["e", "d"]), ("d", ["e"]),
         ("e", [])],
        heads: ["a"])
    else { return }
    
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
     h-------e-d------a
      \-g-f-X----c-b-/
  */
  func testCrossover()
  {
    guard let history = makeHistory(
      [("a", ["d", "b"]), ("b", ["c"]), ("c", ["h"]), ("d", ["e"]),
       ("e", ["h", "f"]), ("f", ["g"]), ("g", ["h"]), ("h", [])],
      heads: ["a", "b", "f"])
    else { return }
    
    history.entries.sort(by: { $0.commit.sha < $1.commit.sha })
    
    let connections = generateConnections(history)
    
    let aToD = CommitConnection(parentOID: §"d", childOID: §"a", colorIndex: 0)
    let aToB = CommitConnection(parentOID: §"b", childOID: §"a", colorIndex: 1)
    let bToC = CommitConnection(parentOID: §"c", childOID: §"b", colorIndex: 1)
    let cToH = CommitConnection(parentOID: §"h", childOID: §"c", colorIndex: 1)
    let dToE = CommitConnection(parentOID: §"e", childOID: §"d", colorIndex: 0)
    let eToH = CommitConnection(parentOID: §"h", childOID: §"e", colorIndex: 0)
    let eToF = CommitConnection(parentOID: §"f", childOID: §"e", colorIndex: 2)
    let fToG = CommitConnection(parentOID: §"g", childOID: §"f", colorIndex: 2)
    let gToH = CommitConnection(parentOID: §"h", childOID: §"g", colorIndex: 2)

    XCTAssertEqual(connections[0], [aToD, aToB])
    XCTAssertEqual(connections[1], [aToD, aToB, bToC])
    XCTAssertEqual(connections[2], [aToD, bToC, cToH])
    XCTAssertEqual(connections[3], [aToD, dToE, cToH])
    XCTAssertEqual(connections[4], [dToE, eToH, cToH, eToF])
    XCTAssertEqual(connections[5], [eToH, cToH, eToF, fToG])
    XCTAssertEqual(connections[6], [eToH, cToH, fToG, gToH])
    XCTAssertEqual(connections[7], [eToH, cToH, gToH])
  }
}
