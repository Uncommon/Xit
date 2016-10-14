import XCTest
@testable import Xit


class XTCommitLinesTest: XCTestCase
{
  // Only the SHA/OID matters
  let entry = CommitEntry(commit: MockCommit(sha: "a",
                                             oid: GTOID(oid: "a"),
                                             parentOIDs: []))
  
  //  a
  //  |\
  //  b c
  func testMerge1()
  {
    entry.connections = [
      CommitConnection(parentSHA: "b", childSHA: "a", colorIndex: 0),
      CommitConnection(parentSHA: "c", childSHA: "a", colorIndex: 0),
    ]
    
    XCTAssertEqual(entry.dotOffset, 0)
    XCTAssertEqual(entry.dotColorIndex, 0)
    
    XCTAssertEqual(entry.lines[0].parentIndex, 0)
    XCTAssertNil(entry.lines[0].childIndex)
    XCTAssertEqual(entry.lines[1].parentIndex, 1)
    XCTAssertNil(entry.lines[1].childIndex)
  }
  
  
  // 0
  // | a
  // |/|
  // b c
  func testMerge2()
  {
    entry.connections = [
      CommitConnection(parentSHA: "b", childSHA: "0", colorIndex: 0),
      CommitConnection(parentSHA: "b", childSHA: "a", colorIndex: 1),
      CommitConnection(parentSHA: "c", childSHA: "a", colorIndex: 2)
    ]
    
    XCTAssertEqual(entry.dotOffset, 1)
    XCTAssertEqual(entry.dotColorIndex, 1)
    XCTAssertEqual(entry.lines[0].parentIndex, 0)
    XCTAssertEqual(entry.lines[0].childIndex, 0)
    XCTAssertEqual(entry.lines[1].parentIndex, 0)
    XCTAssertNil(entry.lines[1].childIndex)
    XCTAssertEqual(entry.lines[2].parentIndex, 1)
    XCTAssertNil(entry.lines[2].childIndex)
  }
  
  // 0 1
  // | |
  // | a
  // | |
  // b c
  func testParallel()
  {
    entry.connections = [
      CommitConnection(parentSHA: "b", childSHA: "0", colorIndex: 0),
      CommitConnection(parentSHA: "a", childSHA: "1", colorIndex: 1),
      CommitConnection(parentSHA: "c", childSHA: "a", colorIndex: 1)
    ]
    
    XCTAssertEqual(entry.dotOffset, 1)
    XCTAssertEqual(entry.dotColorIndex, 1)
    XCTAssertEqual(entry.lines[0].parentIndex, 0)
    XCTAssertEqual(entry.lines[0].childIndex, 0)
    XCTAssertNil(entry.lines[1].parentIndex)
    XCTAssertEqual(entry.lines[1].childIndex, 1)
    XCTAssertEqual(entry.lines[2].parentIndex, 1)
    XCTAssertNil(entry.lines[2].childIndex)
  }
  
  // 0 1
  // | |
  // a |
  // |/
  // b
  func testSplitBelow()
  {
    entry.connections = [
      CommitConnection(parentSHA: "a", childSHA: "0", colorIndex: 0),
      CommitConnection(parentSHA: "b", childSHA: "a", colorIndex: 0),
      CommitConnection(parentSHA: "b", childSHA: "1", colorIndex: 1)
    ]
    
    XCTAssertEqual(entry.dotOffset, 0)
    XCTAssertEqual(entry.dotColorIndex, 0)
    XCTAssertNil(entry.lines[0].parentIndex)
    XCTAssertEqual(entry.lines[0].childIndex, 0)
    XCTAssertEqual(entry.lines[1].parentIndex, 0)
    XCTAssertNil(entry.lines[1].childIndex)
    XCTAssertEqual(entry.lines[2].childIndex, 1)
    XCTAssertEqual(entry.lines[2].parentIndex, 0)
  }
  
  // |/
  // |
  // o
  func testSplitAbove()
  {
    entry.connections = [
      CommitConnection(parentSHA: "a", childSHA: "0", colorIndex: 0),
      CommitConnection(parentSHA: "a", childSHA: "1", colorIndex: 1)
    ]
    
    XCTAssertEqual(entry.dotOffset, 0)
    XCTAssertEqual(entry.dotColorIndex, 0)
    XCTAssertNil(entry.lines[0].parentIndex)
    XCTAssertEqual(entry.lines[0].childIndex, 0)
    XCTAssertNil(entry.lines[1].parentIndex)
    XCTAssertEqual(entry.lines[1].childIndex, 0)
  }
  
  // 0 1 2 3
  // | | | |
  // | a / |
  // | |/ /
  // b c d
  func testSplitBelow2()
  {
    entry.connections = [
      CommitConnection(parentSHA: "b", childSHA: "0", colorIndex: 0),
      CommitConnection(parentSHA: "a", childSHA: "1", colorIndex: 1),
      CommitConnection(parentSHA: "c", childSHA: "a", colorIndex: 1),
      CommitConnection(parentSHA: "c", childSHA: "2", colorIndex: 2),
      CommitConnection(parentSHA: "d", childSHA: "3", colorIndex: 3),
    ]
    
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
  
  /* 0 1 2
     |/ /
     |  |
     a  |
     |  |
     b  c
  */
  func testSplitAbove2()
  {
    let entry = CommitEntry(commit: basicCommit())
    
    entry.connections = [
      CommitConnection(parentSHA: "a", childSHA: "0", colorIndex: 0),
      CommitConnection(parentSHA: "b", childSHA: "a", colorIndex: 0),
      CommitConnection(parentSHA: "a", childSHA: "1", colorIndex: 1),
      CommitConnection(parentSHA: "c", childSHA: "2", colorIndex: 2),
    ]
    
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
}
