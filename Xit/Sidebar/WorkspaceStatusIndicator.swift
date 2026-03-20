import Cocoa

final class WorkspaceStatusIndicator: NSButton
{
  init()
  {
    super.init(frame: NSRect(x: 0, y: 0, width: 44, height: 17))
    
    bezelStyle = .inline
    setButtonType(.momentaryPushIn)
    controlSize = .small
    font = NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize)
  }
  
  required init?(coder: NSCoder)
  {
    super.init(coder: coder)
  }
  
  override func hitTest(_ point: NSPoint) -> NSView?
  {
    return nil
  }
  
  func setStatus(unstaged: Int, staged: Int)
  {
    isHidden = unstaged == 0 && staged == 0
    title = "\(unstaged) ▸ \(staged)"
    setFrameSize(intrinsicContentSize)
  }
}
