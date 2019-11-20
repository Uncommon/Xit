import Foundation
import XCTest

extension XCTestCase
{
  func presence(of object: Any) -> XCTestExpectation
  {
    return expectation(for: NSPredicate(format: "exists == 1"), evaluatedWith: object, handler: nil)
  }

  func absence(of object: Any) -> XCTestExpectation
  {
    return expectation(for: NSPredicate(format: "exists == 0"), evaluatedWith: object, handler: nil)
  }
}
