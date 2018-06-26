import Foundation

struct RefToken
{
  #if swift(>=4.2)
  typealias AttrKey = NSAttributedString.Key
  #else
  typealias AttrKey = NSAttributedStringKey
  #endif
  
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
    NSColor.refShine.set()
    path.stroke()
    NSGraphicsContext.restoreGraphicsState()
    
    let fgColor: NSColor = (type == .activeBranch) ? .refActiveText
                                                   : .refText
    let shadow = NSShadow()
    let paragraphStyle = NSParagraphStyle.default.mutableCopy()
                         as! NSMutableParagraphStyle
    
    shadow.shadowBlurRadius = 1.0
    shadow.shadowOffset = NSSize(width: 0, height: -1)
    shadow.shadowColor = (type == .activeBranch) ? .refActiveTextEmboss
                                                 : .refTextEmboss
    paragraphStyle.alignment = .center
    
    let attributes: [AttrKey: Any] = [
          .font: NSFont.refLabelFont,
          .paragraphStyle: paragraphStyle,
          .foregroundColor: fgColor,
          .shadow: shadow]
    let attrText = NSMutableAttributedString(string: text,
                                             attributes: attributes)
    
    if let slashIndex = text.lastIndex(of: "/") {
      attrText.addAttribute(.foregroundColor,
                            value: fgColor.withAlphaComponent(0.6),
                            range: NSRange(text.startIndex...slashIndex,
                                           in: text))
    }
    attrText.draw(in: rect)
    
    type.strokeColor.set()
    path.stroke()
  }
  
  static func rectWidth(for text: String) -> CGFloat
  {
    let size = (text as NSString).size(withAttributes:
          [.font: NSFont.refLabelFont])
    
    return size.width + 12
  }
  
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

extension XTRefType
{
  var strokeColor: NSColor
  {
    switch self {
      case .branch, .activeBranch:
        return .branchStroke
      case .remoteBranch:
        return .remoteBranchStroke
      case .tag:
        return .tagStroke
      default:
        return .refStroke
    }
  }
  
  var gradient: NSGradient
  {
    var start, end: NSColor
    
    switch self {
      case .branch:
        start = .branchGradientStart
        end = .branchGradientEnd
      case .activeBranch:
        start = .activeBranchGradientStart
        end = .activeBranchGradientEnd
      case .remoteBranch:
        start = .remoteGradientStart
        end = .remoteGradientEnd
      case .tag:
        start = .tagGradientStart
        end = .tagGradientEnd
      default:
        start = .refGradientStart
        end = .refGradientEnd
    }
    return NSGradient(starting: start, ending: end) ?? NSGradient()
  }
}

extension NSFont
{
  static var refLabelFont: NSFont { return labelFont(ofSize: 11) }
}

extension NSColor
{
  // Strokes
  static var branchStroke: NSColor
  { return NSColor(named: ◊"branchStroke")! }
  static var remoteBranchStroke: NSColor
  { return NSColor(named: ◊"remoteBranchStroke")! }
  static var tagStroke: NSColor
  { return NSColor(named: ◊"tagStroke")! }
  static var refStroke: NSColor
  { return NSColor(named: ◊"refStroke")! }
  static var refShine: NSColor
  { return NSColor(named: ◊"refShine")! }
  
  // Text
  static var refActiveText: NSColor
  { return NSColor(named: ◊"refActiveText")! }
  static var refActiveTextEmboss: NSColor
  { return NSColor(named: ◊"refActiveTextEmboss")! }
  static var refText: NSColor
  { return NSColor(named: ◊"refText")! }
  static var refTextEmboss: NSColor
  { return NSColor(named: ◊"refTextEmboss")! }
  
  // Gradients
  static var branchGradientStart: NSColor
  { return NSColor(named: ◊"branchGradientStart")! }
  static var branchGradientEnd: NSColor
  { return NSColor(named: ◊"branchGradientEnd")! }
  static var activeBranchGradientStart: NSColor
  { return NSColor(named: ◊"activeBranchGradientStart")! }
  static var activeBranchGradientEnd: NSColor
  { return NSColor(named: ◊"activeBranchGradientEnd")! }
  static var remoteGradientStart: NSColor
  { return NSColor(named: ◊"remoteGradientStart")! }
  static var remoteGradientEnd: NSColor
  { return NSColor(named: ◊"remoteGradientEnd")! }
  static var tagGradientStart: NSColor
  { return NSColor(named: ◊"tagGradientStart")! }
  static var tagGradientEnd: NSColor
  { return NSColor(named: ◊"tagGradientEnd")! }
  static var refGradientStart: NSColor
  { return NSColor(named: ◊"refGradientStart")! }
  static var refGradientEnd: NSColor
  { return NSColor(named: ◊"refGradientEnd")! }
}
