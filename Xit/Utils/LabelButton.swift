import Cocoa

/// A button that ignores clicks. The "inline" button style is supposed to be
/// "for use as a count or label in a source list", but it still handles clicks
/// like a button which isn't appropriate for that.
class LabelButton: NSButton
{
  override func hitTest(_ point: NSPoint) -> NSView?
  {
    return nil
  }
}
