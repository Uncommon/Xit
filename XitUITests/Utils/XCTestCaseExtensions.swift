import Foundation
import XCTest

extension XCTestCase
{
  func presence(of object: Any) -> XCTestExpectation
  {
    return expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: object, handler: nil)
  }

  func absence(of object: Any) -> XCTestExpectation
  {
    return expectation(for: NSPredicate(format: "exists != true"), evaluatedWith: object, handler: nil)
  }
}
