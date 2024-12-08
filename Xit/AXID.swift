import Foundation
import SwiftUI

public struct AXID: RawRepresentable, Sendable
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

extension NSAccessibilityProtocol
{
  func setAccessibilityIdentifier(_ id: AXID)
  {
    setAccessibilityIdentifier(id.rawValue)
  }

  func axid(_ id: AXID) -> Self
  {
    setAccessibilityIdentifier(id.rawValue)
    return self
  }
}

extension View
{
  public func accessibilityIdentifier(_ id: AXID) -> some View
  {
    accessibilityIdentifier(id.rawValue)
  }

  public func axid(_ id: AXID)
    -> ModifiedContent<Self, AccessibilityAttachmentModifier>
  {
    accessibility(identifier: id.rawValue)
  }
}
