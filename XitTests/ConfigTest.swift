import XCTest
@testable import Xit

class ConfigTest: XCTestCase
{
  func testString() throws
  {
    let config = DictionaryConfig()
    let key1 = "key1"
    let key2 = "key2"
    let value1 = "value1"
    let value2 = "value2"

    config.set(value: value1, for: key1)
    config[key2] = value2
    XCTAssertEqual(config[key1], value1)
    XCTAssertEqual(config[key2], value2)

    let stringValue1: String? = config.value(for: key1)
    let stringValue2: String? = config.value(for: key2)

    XCTAssertEqual(stringValue1, value1)
    XCTAssertEqual(stringValue2, value2)
  }

  func testInt() throws
  {
    let config = DictionaryConfig()
    let key1 = "key1"
    let key2 = "key2"
    let value1 = 1
    let value2 = 2

    config.set(value: value1, for: key1)
    config[key2] = value2
    XCTAssertEqual(config[key1], value1)
    XCTAssertEqual(config[key2], value2)

    let stringValue1: Int? = config.value(for: key1)
    let stringValue2: Int? = config.value(for: key2)

    XCTAssertEqual(stringValue1, value1)
    XCTAssertEqual(stringValue2, value2)
  }

  func testBool() throws
  {
    let config = DictionaryConfig()
    let key1 = "key1"
    let key2 = "key2"
    let value1 = true
    let value2 = false

    config.set(value: value1, for: key1)
    config[key2] = value2
    XCTAssertEqual(config[key1], value1)
    XCTAssertEqual(config[key2], value2)

    let stringValue1: Bool? = config.value(for: key1)
    let stringValue2: Bool? = config.value(for: key2)

    XCTAssertEqual(stringValue1, value1)
    XCTAssertEqual(stringValue2, value2)
  }
}
