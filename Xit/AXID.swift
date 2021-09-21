import Foundation
import SwiftUI

public struct AXID: RawRepresentable
{
  public let rawValue: String

  public init(rawValue: String) // make it public
  {
    self.rawValue = rawValue
  }

  public init(_ id: String)
  {
    self.rawValue = id
  }
}

extension NSView
{
  func setAccessibilityIdentifier(_ id: AXID)
  {
    setAccessibilityIdentifier(id.rawValue)
  }
}

extension NSWindow
{
  func setAccessibilityIdentifier(_ id: AXID)
  {
    setAccessibilityIdentifier(id.rawValue)
  }
}

extension View
{
  public func accessibilityIdentifier(_ id: AXID)
    -> ModifiedContent<Self, AccessibilityAttachmentModifier>
  {
    accessibility(identifier: id.rawValue)
  }
}
