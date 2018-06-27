import Cocoa

class ClickThroughImageView: NSImageView
{
  override func hitTest(_ point: NSPoint) -> NSView?
  {
    return nil
  }
}
