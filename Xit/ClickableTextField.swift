import Cocoa

/// An NSTextField label that acts like a button, mainly to achieve
/// ellipsis truncation which NSButton seems unable to do.
class ClickableTextField: NSTextField
{
  var trackingTag: NSView.TrackingRectTag = 0
  
  init(title: String, target: AnyObject, action: Selector)
  {
    super.init(frame: .zero)
    
    stringValue = title
    self.target = target
    self.action = action
    isEditable = false
    isSelectable = false
    isBezeled = false
    drawsBackground = false
    setHilited(false)
    usesSingleLineMode = true
    lineBreakMode = .byTruncatingTail
    allowsExpansionToolTips = true
    setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
  }
  
  required init?(coder: NSCoder)
  {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func mouseDown(with event: NSEvent)
  {
    setHilited(true)
    
    trackingTag = addTrackingRect(bounds, owner: self, userData: nil,
                                  assumeInside: true)
  }
  
  override func mouseUp(with event: NSEvent)
  {
    setHilited(false)
    if NSPointInRect(convert(event.locationInWindow, from: nil), bounds),
       let action = self.action,
       let target = self.target {
      NSApp.sendAction(action, to: target, from: self)
    }
    removeTrackingRect(trackingTag)
  }
  
  override func mouseEntered(with event: NSEvent)
  {
    setHilited(true)
  }
  
  override func mouseExited(with event: NSEvent)
  {
    setHilited(false)
  }
  
  func setHilited(_ hilited: Bool)
  {
    #if swift(>=4.2)
    textColor = hilited ? .textColor : .linkColor
    #else
    textColor = hilited ? .textColor : .blue
    #endif
  }
}
