import Foundation
import XCTest

extension XCTestCase
{
  func presence(of object: Any) -> XCTestExpectation
  {
    expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: object)
  }

  func absence(of object: Any) -> XCTestExpectation
  {
    expectation(for: NSPredicate(format: "exists != true"), evaluatedWith: object)
  }
  
  func hiding(of object: Any) -> XCTestExpectation
  {
    expectation(for: NSPredicate(format: "isHittable != true"), evaluatedWith: object)
  }

  func enabling(of object: Any) -> XCTestExpectation
  {
    expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: object)
  }

  func disabling(of object: Any) -> XCTestExpectation
  {
    expectation(for: NSPredicate(format: "isEnabled != true"), evaluatedWith: object)
  }
}
