import Cocoa

/// A window that posts a notification when its first responder changes.
class ResponderNotifierWindow: NSWindow
{
  override func makeFirstResponder(_ responder: NSResponder?) -> Bool
  {
    let result = super.makeFirstResponder(responder)
    
    if result {
      NotificationCenter.default.post(name: .xtFirstResponderChanged, object: self)
    }
    return result
  }
}

extension Notification.Name
{
  static let xtFirstResponderChanged = Self("firstResponderChanged")
}
