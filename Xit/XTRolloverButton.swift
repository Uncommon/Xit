import Cocoa

class XTRolloverButton: NSButton {

  @IBInspectable var rolloverImage: NSImage?
  var normalImage: NSImage?
  var rolloverActive: Bool

  // Does nothing, but overriding a designated initializer is required
  required init?(coder: NSCoder)
  {
    self.rolloverActive = true
    super.init(coder: coder)
    self.normalImage = self.image
  }

  override func awakeFromNib()
  {
    let tracking = NSTrackingArea(
        rect: self.bounds,
        options: [NSTrackingAreaOptions.MouseEnteredAndExited,
                  NSTrackingAreaOptions.ActiveInActiveApp,
                  NSTrackingAreaOptions.AssumeInside],
        owner: self, userInfo: nil)
    
    self.addTrackingArea(tracking)
  }

  override func mouseEntered(theEvent: NSEvent)
  {
    if self.rolloverActive {
      self.normalImage = self.image
      self.image = self.rolloverImage
      self.setNeedsDisplay()
    }
  }
  
  override func mouseExited(theEvent: NSEvent)
  {
    self.image = self.normalImage
    self.setNeedsDisplay()
  }
}
