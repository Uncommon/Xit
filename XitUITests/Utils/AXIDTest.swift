import Foundation
import XCTest

extension XCUIElementQuery
{
  subscript(key: AXID) -> XCUIElement
  { self[key.rawValue] }

  func matching(identifier: AXID) -> XCUIElementQuery
  { matching(identifier: identifier.rawValue) }

  func matching(_ elementType: XCUIElement.ElementType,
                identifier: AXID) -> XCUIElementQuery
  { matching(elementType, identifier: identifier.rawValue) }

  func containing(_ elementType: XCUIElement.ElementType,
                  identifier: AXID) -> XCUIElementQuery
  { containing(elementType, identifier: identifier.rawValue) }

  func element(matching elementType: XCUIElement.ElementType,
               identifier: AXID) -> XCUIElement
  { element(matching: elementType, identifier: identifier.rawValue) }
}
