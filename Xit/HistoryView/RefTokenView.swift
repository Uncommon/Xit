import Foundation

class RefTokenView: NSView
{
  #if swift(>=4.2)
  typealias AttrKey = NSAttributedString.Key
  #else
  typealias AttrKey = NSAttributedStringKey
  #endif
  
  var text: String = ""
  var type: RefType = .unknown
  
  override var intrinsicContentSize: NSSize
  {
    let size = (text as NSString).size(withAttributes:
          [.font: NSFont.refLabelFont])
    
    return NSSize(width: size.width + 12, height: 17)
  }
  
  override func contentHuggingPriority(
      for orientation: NSLayoutConstraint.Orientation)
    -> NSLayoutConstraint.Priority
  {
    return .required
  }
  
  override func contentCompressionResistancePriority(
      for orientation: NSLayoutConstraint.Orientation)
    -> NSLayoutConstraint.Priority
  {
    return .required
  }
  
  override func draw(_ dirtyRect: NSRect)
  {
    let path = self.makePath()
    let gradient = type.gradient
    let transform = NSAffineTransform()
    
    gradient.draw(in: path, angle: 270)
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    transform.translateX(by: 0, yBy: -1)
    transform.concat()
    NSColor.refTokenStroke(.shine).set()
    path.stroke()
    NSGraphicsContext.restoreGraphicsState()
    
    let active = type == .activeBranch
    let fgColor: NSColor = .refTokenText(active ? .active : .normal)
    let shadow = NSShadow()
    let paragraphStyle = NSParagraphStyle.default.mutableCopy()
                         as! NSMutableParagraphStyle
    
    shadow.shadowBlurRadius = 1.0
    shadow.shadowOffset = NSSize(width: 0, height: -1)
    shadow.shadowColor = .refTokenText(active ? .activeEmboss : .normalEmboss)
    paragraphStyle.alignment = .center
    paragraphStyle.lineBreakMode = .byTruncatingMiddle
    
    let attributes: [AttrKey: Any] = [
          .font: NSFont.refLabelFont,
          .paragraphStyle: paragraphStyle,
          .foregroundColor: fgColor,
          .shadow: shadow]
    let attrText = NSMutableAttributedString(string: text,
                                             attributes: attributes)
    
    if let slashIndex = text.lastIndex(of: "/") {
      let pathRange = NSRange(text.startIndex...slashIndex, in: text)
      
      attrText.addAttribute(.foregroundColor,
                            value: fgColor.withAlphaComponent(0.6),
                            range: pathRange)
      attrText.removeAttribute(.shadow, range: pathRange)
    }
    attrText.draw(in: bounds)
    
    type.strokeColor.set()
    path.stroke()
  }
  
  private func makePath() -> NSBezierPath
  {
    // Inset because the stroke will be centered on the path border
    var rect = bounds.insetBy(dx: 0.5, dy: 1.5)
    
    rect.origin.y += 1
    rect.size.height -= 1
    
    switch type {
      case .branch, .activeBranch:
        let radius = rect.size.height / 2
      
        return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
      
      case .tag:
        let path = NSBezierPath()
        let cornerInset: CGFloat = 5
        let top = rect.origin.y
        let left = rect.origin.x
        let bottom = top + rect.size.height
        let right = left + rect.size.width
        let leftInset = left + cornerInset
        let rightInset = right - cornerInset
        let middle = top + rect.size.height / 2
      
        path.move(to: NSPoint(x: leftInset, y: top))
        path.line(to: NSPoint(x: rightInset, y: top))
        path.line(to: NSPoint(x: right, y: middle))
        path.line(to: NSPoint(x: rightInset, y: bottom))
        path.line(to: NSPoint(x: leftInset, y: bottom))
        path.line(to: NSPoint(x: left, y: middle))
        path.close()
        return path
      
      default:
        return NSBezierPath(rect: rect)
    }
  }
}

extension NSFont
{
  static var refLabelFont: NSFont { return labelFont(ofSize: 11) }
}
