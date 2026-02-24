import XCTest
@testable import XitGit

final class ArrayExtensionsTest: XCTestCase
{
  func testSortedInsertionIndexEmptyArrayReturnsZero()
  {
    let values: [Int] = []

    let index = values.sortedInsertionIndex(of: 5, isOrderedBefore: <)

    XCTAssertEqual(index, 0)
  }
}
