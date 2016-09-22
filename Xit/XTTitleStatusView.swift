import Cocoa

class XTTitleStatusView: NSView
{
  override var mouseDownCanMoveWindow: Bool { return true }
}


class XTDraggingButton : NSButton
{
  override var mouseDownCanMoveWindow: Bool { return true }
}

class XTDraggingLabel : NSTextField
{
  override var mouseDownCanMoveWindow: Bool { return true }
}

class XTDraggingImage : NSImageView
{
  override var mouseDownCanMoveWindow: Bool { return true }
}

class XTDraggingProgress : NSProgressIndicator
{
  override var mouseDownCanMoveWindow: Bool { return true }
}
