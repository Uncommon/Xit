import Cocoa

/// A view with flipped coordinates. In particular, it's useful as the
/// content view for a scroll view so that the scroll origin is at the
/// top instead of the bottom.
class FlippedView: NSView
{
  override var isFlipped: Bool { return true }
}
