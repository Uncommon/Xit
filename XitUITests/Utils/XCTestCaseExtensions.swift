import Foundation
import XCTest

extension XCTestCase
{
  func presence(of object: Any) -> XCTestExpectation
  {
    expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: object, handler: nil)
  }

  func absence(of object: Any) -> XCTestExpectation
  {
    expectation(for: NSPredicate(format: "exists != true"), evaluatedWith: object, handler: nil)
  }
  
  func hiding(of object: Any) -> XCTestExpectation
  {
    expectation(for: NSPredicate(format: "isHittable != true"), evaluatedWith: object, handler: nil)
  }
}
