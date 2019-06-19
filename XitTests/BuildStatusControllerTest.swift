import XCTest
@testable import Xit

class BuildStatusControllerTest: XCTestCase
{
  func testDisplayStateUnknown()
  {
    var s = BuildStatusController.DisplayState.unknown
    
    for state in BuildStatusController.DisplayState.allCases {
      s += state
      XCTAssertEqual(s, state)
    }
  }
  
  func testDisplayStateSuccess()
  {
    var s = BuildStatusController.DisplayState.success
    
    s += .unknown
    XCTAssertEqual(s, .success)
    s += .success
    XCTAssertEqual(s, .success)
    s += .running
    XCTAssertEqual(s, .running)
    s += .failure
    XCTAssertEqual(s, .failure)
  }
  
  func testDisplayStateRunning()
  {
    var s = BuildStatusController.DisplayState.running
    
    s += .unknown
    XCTAssertEqual(s, .running)
    s += .success
    XCTAssertEqual(s, .running)
    s += .running
    XCTAssertEqual(s, .running)
    s += .failure
    XCTAssertEqual(s, .failure)
  }
  
  func testDisplayStateFailure()
  {
    var s = BuildStatusController.DisplayState.failure
    
    for state in BuildStatusController.DisplayState.allCases {
      s += state
      XCTAssertEqual(s, .failure)
    }
  }
}
