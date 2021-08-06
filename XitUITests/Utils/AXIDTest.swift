import Foundation
import XCTest

extension XCUIElementQuery
{
  subscript(key: AXID) -> XCUIElement
  { self[key.rawValue] }

  func matching(identifier: AXID) -> XCUIElementQuery
  { matching(identifier: identifier.rawValue) }
}
