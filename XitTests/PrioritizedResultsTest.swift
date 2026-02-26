import Foundation
import XCTest
@testable import Xit

final class PrioritizedResultsTest: XCTestCase
{
  private enum OrderedChecks: String, CaseIterable
  {
    case first
    case second
    case third
  }

  func testPFirstErrorRespectsEnumOrder()
  {
    var results = ProritizedResults<OrderedChecks>()
    let firstFailure = NSError(domain: "PrioritizedResultsTest", code: 1)
    let secondFailure = NSError(domain: "PrioritizedResultsTest", code: 2)

    // If an earlier check has no result yet, later errors should not surface.
    results.second = Result<Void, NSError>.failure(secondFailure)
    XCTAssertNil(results.firstError)

    // Once prior checks succeed, the first failing check in enum order wins.
    results.first = Result<Void, NSError>.success(())
    XCTAssertEqual((results.firstError as NSError?)?.code, secondFailure.code)

    results.first = Result<Void, NSError>.failure(firstFailure)
    XCTAssertEqual((results.firstError as NSError?)?.code, firstFailure.code)

    // allSucceeded should require all enum cases to be successful.
    XCTAssertFalse(results.allSucceeded)
    results.first = Result<Void, NSError>.success(())
    results.second = Result<Void, NSError>.success(())
    results.third = Result<Void, NSError>.success(())
    XCTAssertTrue(results.allSucceeded)
    XCTAssertNil(results.firstError)
  }
}
