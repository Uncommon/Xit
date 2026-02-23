import XCTest
@testable import XitGit

final class CacheTest: XCTestCase
{
  func testCache()
  {
    let cache = Cache<String, Int>(maxSize: 3)
    
    cache["a"] = 1
    usleep(100)  // Make sure the dates will be different
    cache["b"] = 2
    usleep(100)
    cache["c"] = 3
    usleep(100)
    cache["d"] = 4

    // Adding d should have purged a
    XCTAssertNil(cache["a"])
    XCTAssertEqual(cache["b"], 2)
    cache.maxSize = 2

    // c got dropped because b was accessed last
    XCTAssertNil(cache["c"])
    XCTAssertEqual(cache["b"], 2)
    XCTAssertEqual(cache["d"], 4)
  }
}
