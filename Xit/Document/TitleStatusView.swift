import Cocoa

class TitleStatusView: NSView
{
  override var mouseDownCanMoveWindow: Bool { true }
}


class DraggingButton: NSButton
{
  override var mouseDownCanMoveWindow: Bool { true }
}

class DraggingLabel: NSTextField
{
  override var mouseDownCanMoveWindow: Bool { true }
}

class DraggingImage: NSImageView
{
  override var mouseDownCanMoveWindow: Bool { true }
}

class DraggingProgress: NSProgressIndicator
{
  override var mouseDownCanMoveWindow: Bool { true }
}
