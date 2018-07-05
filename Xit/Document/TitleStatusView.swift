import Cocoa

class TitleStatusView: NSView
{
  override var mouseDownCanMoveWindow: Bool { return true }
}


class DraggingButton: NSButton
{
  override var mouseDownCanMoveWindow: Bool { return true }
}

class DraggingLabel: NSTextField
{
  override var mouseDownCanMoveWindow: Bool { return true }
}

class DraggingImage: NSImageView
{
  override var mouseDownCanMoveWindow: Bool { return true }
}

class DraggingProgress: NSProgressIndicator
{
  override var mouseDownCanMoveWindow: Bool { return true }
}
