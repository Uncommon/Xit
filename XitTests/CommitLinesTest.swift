import XCTest
@testable import Xit
import XitGit

class CommitLinesTest: XCTestCase
{
  // Only the SHA/OID matters
  let entry = CommitEntry(commit: StringCommit(parentOIDs: [], id: "a"))
  let history = CommitHistory<StringCommit>()
  
  override func setUp()
  {
    super.setUp()
    
    history.entries.append(entry)
  }
  
  
  //  a
  //  |\
  //  b c
  func testMerge1()
  {
    history.generateLines(entry: entry, connections: [
      CommitConnection(parentOID: "b", childOID: "a", colorIndex: 0),
      CommitConnection(parentOID: "c", childOID: "a", colorIndex: 1),
    ])
    
    XCTAssertEqual(entry.dotOffset, 0)
    XCTAssertEqual(entry.dotColorIndex, 0)
    
    XCTAssertEqual(entry.lines[0].parentIndex, 0)
    XCTAssertNil(entry.lines[0].childIndex)
    XCTAssertEqual(entry.lines[0].colorIndex, 0)
    XCTAssertEqual(entry.lines[1].parentIndex, 1)
    XCTAssertNil(entry.lines[1].childIndex)
    XCTAssertEqual(entry.lines[1].colorIndex, 1)
  }
  
  
  // 0
  // | a
  // |/|
  // b c
  func testMerge2()
  {
    history.generateLines(entry: entry, connections: [
      CommitConnection(parentOID: "b", childOID: "0", colorIndex: 0),
      CommitConnection(parentOID: "b", childOID: "a", colorIndex: 1),
      CommitConnection(parentOID: "c", childOID: "a", colorIndex: 2)
    ])
    
    XCTAssertEqual(entry.dotOffset, 1)
    XCTAssertEqual(entry.dotColorIndex, 1)
    XCTAssertEqual(entry.lines[0].parentIndex, 0)
    XCTAssertEqual(entry.lines[0].childIndex, 0)
    XCTAssertEqual(entry.lines[0].colorIndex, 0)
    XCTAssertEqual(entry.lines[1].parentIndex, 0)
    XCTAssertNil(entry.lines[1].childIndex)
    XCTAssertEqual(entry.lines[1].colorIndex, 1)
    XCTAssertEqual(entry.lines[2].parentIndex, 1)
    XCTAssertNil(entry.lines[2].childIndex)
    XCTAssertEqual(entry.lines[2].colorIndex, 2)
  }
  
  // 0 1
  // | |
  // | a
  // | |
  // b c
  func testParallel()
  {
    history.generateLines(entry: entry, connections: [
      CommitConnection(parentOID: "b", childOID: "0", colorIndex: 0),
      CommitConnection(parentOID: "a", childOID: "1", colorIndex: 1),
      CommitConnection(parentOID: "c", childOID: "a", colorIndex: 1)
    ])
    
    XCTAssertEqual(entry.dotOffset, 1)
    XCTAssertEqual(entry.dotColorIndex, 1)
    XCTAssertEqual(entry.lines[0].parentIndex, 0)
    XCTAssertEqual(entry.lines[0].childIndex, 0)
    XCTAssertEqual(entry.lines[0].colorIndex, 0)
    XCTAssertNil(entry.lines[1].parentIndex)
    XCTAssertEqual(entry.lines[1].childIndex, 1)
    XCTAssertEqual(entry.lines[1].colorIndex, 1)
    XCTAssertEqual(entry.lines[2].parentIndex, 1)
    XCTAssertNil(entry.lines[2].childIndex)
    XCTAssertEqual(entry.lines[2].colorIndex, 1)
  }
  
  // 0 1
  // | |
  // a |
  // |/
  // b
  func testSplitBelow()
  {
    history.generateLines(entry: entry, connections: [
      CommitConnection(parentOID: "a", childOID: "0", colorIndex: 0),
      CommitConnection(parentOID: "b", childOID: "a", colorIndex: 0),
      CommitConnection(parentOID: "b", childOID: "1", colorIndex: 1)
    ])
    
    XCTAssertEqual(entry.dotOffset, 0)
    XCTAssertEqual(entry.dotColorIndex, 0)
    XCTAssertNil(entry.lines[0].parentIndex)
    XCTAssertEqual(entry.lines[0].childIndex, 0)
    XCTAssertEqual(entry.lines[0].colorIndex, 0)
    XCTAssertEqual(entry.lines[1].parentIndex, 0)
    XCTAssertNil(entry.lines[1].childIndex)
    XCTAssertEqual(entry.lines[1].colorIndex, 0)
    XCTAssertEqual(entry.lines[2].childIndex, 1)
    XCTAssertEqual(entry.lines[2].parentIndex, 0)
    XCTAssertEqual(entry.lines[2].colorIndex, 1)
  }
  
  // |/
  // |
  // o
  func testSplitAbove()
  {
    history.generateLines(entry: entry, connections: [
      CommitConnection(parentOID: "a", childOID: "0", colorIndex: 0),
      CommitConnection(parentOID: "a", childOID: "1", colorIndex: 1)
    ])
    
    XCTAssertEqual(entry.dotOffset, 0)
    XCTAssertEqual(entry.dotColorIndex, 0)
    XCTAssertNil(entry.lines[0].parentIndex)
    XCTAssertEqual(entry.lines[0].childIndex, 0)
    XCTAssertEqual(entry.lines[0].colorIndex, 0)
    XCTAssertNil(entry.lines[1].parentIndex)
    XCTAssertEqual(entry.lines[1].childIndex, 0)
    XCTAssertEqual(entry.lines[1].colorIndex, 0)
  }
  
  // 0 1 2 3
  // | | | |
  // | a / |
  // | |/ /
  // b c d
  func testSplitBelow2()
  {
    history.generateLines(entry: entry, connections: [
      CommitConnection(parentOID: "b", childOID: "0", colorIndex: 0),
      CommitConnection(parentOID: "a", childOID: "1", colorIndex: 1),
      CommitConnection(parentOID: "c", childOID: "a", colorIndex: 1),
      CommitConnection(parentOID: "c", childOID: "2", colorIndex: 2),
      CommitConnection(parentOID: "d", childOID: "3", colorIndex: 3),
    ])
    
    XCTAssertEqual(entry.dotOffset, 1)
    XCTAssertEqual(entry.dotColorIndex, 1)
    XCTAssertEqual(entry.lines[0].parentIndex, 0)
    XCTAssertEqual(entry.lines[0].childIndex, 0)
    XCTAssertNil(entry.lines[1].parentIndex)
    XCTAssertEqual(entry.lines[1].childIndex, 1)
    XCTAssertEqual(entry.lines[2].parentIndex, 1)
    XCTAssertNil(entry.lines[2].childIndex)
    XCTAssertEqual(entry.lines[3].parentIndex, 1)
    XCTAssertEqual(entry.lines[3].childIndex, 2)
    XCTAssertEqual(entry.lines[4].parentIndex, 2)
    XCTAssertEqual(entry.lines[4].childIndex, 3)
  }
  
  // 0 1 2
  // | | |
  // | a /
  // |/ /
  // b c
  func testSplitBelow3()
  {
    history.generateLines(entry: entry, connections: [
      CommitConnection(parentOID: "b", childOID: "0", colorIndex: 0),
      CommitConnection(parentOID: "a", childOID: "1", colorIndex: 1),
      CommitConnection(parentOID: "b", childOID: "a", colorIndex: 1),
      CommitConnection(parentOID: "c", childOID: "2", colorIndex: 2),
    ])
    
    XCTAssertEqual(entry.dotOffset, 1)
    XCTAssertEqual(entry.dotColorIndex, 1)
    XCTAssertEqual(entry.lines[0].parentIndex, 0)
    XCTAssertEqual(entry.lines[0].childIndex, 0)
    XCTAssertNil(entry.lines[1].parentIndex)
    XCTAssertEqual(entry.lines[1].childIndex, 1)
    XCTAssertEqual(entry.lines[2].parentIndex, 0)
    XCTAssertNil(entry.lines[2].childIndex)
    XCTAssertEqual(entry.lines[3].parentIndex, 1)
    XCTAssertEqual(entry.lines[3].childIndex, 2)
  }
  
  // 0 1 2
  // |/ /
  // |  |
  // a  |
  // |  |
  // b  c
  func testSplitAbove2()
  {
    history.generateLines(entry: entry, connections: [
      CommitConnection(parentOID: "a", childOID: "0", colorIndex: 0),
      CommitConnection(parentOID: "b", childOID: "a", colorIndex: 0),
      CommitConnection(parentOID: "a", childOID: "1", colorIndex: 1),
      CommitConnection(parentOID: "c", childOID: "2", colorIndex: 2),
    ])
    
    XCTAssertEqual(entry.dotOffset, 0)
    XCTAssertEqual(entry.dotColorIndex, 0)
    XCTAssertNil(entry.lines[0].parentIndex)
    XCTAssertEqual(entry.lines[0].childIndex, 0)
    XCTAssertEqual(entry.lines[1].parentIndex, 0)
    XCTAssertNil(entry.lines[1].childIndex)
    XCTAssertNil(entry.lines[2].parentIndex)
    XCTAssertEqual(entry.lines[2].childIndex, 0)
    XCTAssertEqual(entry.lines[3].parentIndex, 1)
    XCTAssertEqual(entry.lines[3].childIndex, 1)
  }
  
  // 0 1 2
  // |/ /
  // |  |
  // |  a
  // |  |
  // b  c
  func testMergedParallel()
  {
    history.generateLines(entry: entry, connections: [
      CommitConnection(parentOID: "b", childOID: "0", colorIndex: 0),
      CommitConnection(parentOID: "b", childOID: "1", colorIndex: 1),
      CommitConnection(parentOID: "a", childOID: "2", colorIndex: 2),
      CommitConnection(parentOID: "c", childOID: "a", colorIndex: 2),
    ])

    XCTAssertEqual(entry.dotOffset, 1)
    XCTAssertEqual(entry.dotColorIndex, 2)
    XCTAssertEqual(entry.lines[0].parentIndex, 0)
    XCTAssertEqual(entry.lines[0].childIndex, 0)
    XCTAssertEqual(entry.lines[1].parentIndex, 0)
    XCTAssertEqual(entry.lines[1].childIndex, 0)
    XCTAssertNil(entry.lines[2].parentIndex)
    XCTAssertEqual(entry.lines[2].childIndex, 1)
    XCTAssertEqual(entry.lines[3].parentIndex, 1)
    XCTAssertNil(entry.lines[3].childIndex)
  }
}
