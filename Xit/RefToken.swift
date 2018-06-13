import Foundation

struct RefToken
{
  static func drawToken(refType type: XTRefType, text: String, rect: NSRect)
  {
    let path = self.path(for: type, rect: rect)
    let gradient = type.gradient
    let transform = NSAffineTransform()
    
    gradient.draw(in: path, angle: 270)
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    transform.translateX(by: 0, yBy: -1)
    transform.concat()
    NSColor.init(deviceWhite: 1, alpha: 0.4).set()
    path.stroke()
    NSGraphicsContext.restoreGraphicsState()
    
    let fgColor: NSColor = (type == .activeBranch) ? .white : .black
    let shadow = NSShadow()
    let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    
    shadow.shadowBlurRadius = 1.0
    shadow.shadowOffset = NSMakeSize(0, -1)
    shadow.shadowColor = (type == .activeBranch) ? .black : .white
    paragraphStyle.alignment = .center
    
    let attributes: [NSAttributedString.Key: Any] = [
          .font: labelFont,
          .paragraphStyle: paragraphStyle,
          .foregroundColor: fgColor,
          .shadow: shadow]
    let attrText = NSMutableAttributedString(string: text,
                                             attributes: attributes)
    
    if let slashIndex = text.lastIndex(of: "/") {
      attrText.addAttribute(.foregroundColor,
                            value: NSColor(deviceWhite: 0, alpha: 0.6),
                            range: NSRange(text.startIndex...slashIndex,
                                           in: text))
    }
    attrText.draw(in: rect)
    
    type.strokeColor.set()
    path.stroke()
  }
  
  static func rectWidth(for text: String) -> CGFloat
  {
    let attributes: [NSAttributedString.Key: AnyObject] = [.font: labelFont]
    let size = (text as NSString).size(withAttributes: attributes)
    
    return size.width + 12
  }
  
  static var labelFont: NSFont { return NSFont(name: "Helvetica", size: 11)! }
  
  private static func path(for type: XTRefType, rect: NSRect) -> NSBezierPath
  {
    // Inset because the stroke will be centered on the path border
    var rect = rect.insetBy(dx: 0.5, dy: 1.5)
    
    rect.origin.y += 1
    rect.size.height -= 1
    
    switch type {
      case .branch, .activeBranch:
        let radius = rect.size.height / 2
      
        return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
      case .tag:
        let path = NSBezierPath()
        let cornerInset: CGFloat = 5;
        let top = rect.origin.y
        let left = rect.origin.x
        let bottom = top + rect.size.height
        let right = left + rect.size.width
        let leftInset = left + cornerInset
        let rightInset = right - cornerInset
        let middle = top + rect.size.height / 2;
      
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
  
  static func gradient(hue: CGFloat, saturation: CGFloat, active: Bool)
    -> NSGradient
  {
    let startBrightness: CGFloat = active ? 0.75 : 1.0
    let endBrightness: CGFloat = active ? 0.6 : 0.8
    let startColor = NSColor(deviceHue: hue / 360.0,
                             saturation: saturation / 100.0,
                             brightness: startBrightness, alpha: 1.0)
    let endColor = NSColor(deviceHue: hue / 360.0,
                           saturation: saturation / 100.0,
                           brightness: endBrightness, alpha: 1.0)
    
    return NSGradient(starting: startColor, ending: endColor) ?? NSGradient()
  }
}

extension XTRefType
{
  var strokeColor: NSColor
  {
    var hue: CGFloat = 0.0
    var saturation: CGFloat = 0.74
    
    switch self {
      case .branch, .activeBranch:
        hue = 100
      case .remoteBranch:
        hue = 150
      case .tag:
        hue = 40
      default:
        saturation = 0
    }
    return NSColor(deviceHue: hue / 360.0, saturation: saturation,
                   brightness: 0.55, alpha: 1)
  }
  
  var gradient: NSGradient
  {
    switch self {
      case .branch:
        return RefToken.gradient(hue: 100, saturation: 60, active: false)
      case .activeBranch:
        return RefToken.gradient(hue: 100, saturation: 85, active: true)
      case .remoteBranch:
        return RefToken.gradient(hue: 150, saturation: 15, active: false)
      case .tag:
        return RefToken.gradient(hue: 42, saturation: 30, active: false)
      default:
        return RefToken.gradient(hue: 0, saturation: 0, active: false)
    }
  }
}
