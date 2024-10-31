import Foundation
import XCTest
@testable import Xit

class SHATest: XCTestCase
{
  func testZero()
  {
    let zero = SHA.zero
    let zeroCopy = SHA(zero.rawValue)

    XCTAssertNotNil(zeroCopy)
  }

  func testTooShort()
  {
    XCTAssertNil(SHA(rawValue: "000"))
  }

  func testTooLong()
  {
    XCTAssertNil(SHA(String(repeating: "0", count: SHA.standardLength + 1)))
  }

  func testGood()
  {
    XCTAssertNotNil(SHA("918175ee7c393a3f0d548a976f0061990c20e8d4"))
  }
}
