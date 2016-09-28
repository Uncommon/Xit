import Cocoa

/// Cell view that draws the graph lines next to the text.
class XTHistoryCellView: NSTableCellView
{
  var refs = [String]()
  
  /// Margin of space to leave for the lines in this cell.
  fileprivate var linesMargin: CGFloat = 0.0
  
  static let lineColors = [
      NSColor.blue, NSColor.green, NSColor.red,
      NSColor.brown, NSColor.cyan, NSColor.darkGray,
      NSColor.magenta, NSColor.orange, NSColor.purple,
      // Regular yellow is too light
      NSColor(calibratedHue: 0.13, saturation: 0.08, brightness: 0.8, alpha: 1.0),
      NSColor.black, NSColor.lightGray]
  
  static let columnWidth: CGFloat = 8.0
  static let leftMargin: CGFloat = 4.0
  static let rightMargin: CGFloat = 4.0
  static let textMargin: CGFloat = 4.0
  static let tokenMargin: CGFloat = 4.0

  /// Finds the center of the given column.
  static func columnCenter(_ index: UInt) -> CGFloat
  {
    return leftMargin + columnWidth * CGFloat(index) + columnWidth / 2
  }
  
  /// Counts the different kinds of connections passing through a commit.
  static func count(connections: [CommitConnection], oid: GTOID)
    -> (incoming: UInt, outgoing: UInt, through: UInt)
  {
    var incomingCount: UInt = 0, outgoingCount: UInt = 0, throughCount: UInt = 0
    
    for connection in connections {
      let incoming = connection.parentOID == oid
      let outgoing = connection.childOID == oid
      
      incomingCount += incoming ? 1 : 0
      outgoingCount += outgoing ? 1 : 0
      throughCount += !(incoming || outgoing) ? 1 : 0
    }
    return (incomingCount, outgoingCount, throughCount)
  }
  
  /// Moves the text field out of the way of the lines and refs.
  func adjustLayout()
  {
    guard let entry = objectValue as? CommitEntry
    else { return }
    let oid = entry.commit.oid
    
    let (incomingCount, outgoingCount, throughCount) =
        XTHistoryCellView.count(connections: entry.connections, oid: oid)
    let totalColumns = throughCount + max(incomingCount, outgoingCount)
    
    linesMargin = XTHistoryCellView.leftMargin +
                  CGFloat(totalColumns) * XTHistoryCellView.columnWidth
    
    let tokenWidth: CGFloat = refs.reduce(0.0) { (width, ref) -> CGFloat in
      guard let (_, displayRef) = ref.splitRefName()
      else { return 0 }
      return XTRefToken.rectWidth(text: displayRef) +
             width + XTHistoryCellView.tokenMargin
    }
    
    if let textField = textField {
      var newFrame = textField.frame
      
      newFrame.origin.x = tokenWidth + linesMargin + XTHistoryCellView.textMargin
      newFrame.size.width = frame.size.width - newFrame.origin.x -
                            XTHistoryCellView.rightMargin
      textField.frame = newFrame
    }
  }
  
  /// Draws the graph lines and refs in the view.
  override func draw(_ dirtyRect: NSRect)
  {
    super.draw(dirtyRect)
    
    adjustLayout()
    drawRefs()
    drawLines()
  }
  
  static func refType(_ typeName: String) -> XTRefType
  {
    switch typeName {
      case "refs/heads/":
        return .branch
      case "refs/remotes/":
        return .remoteBranch
      case "refs/tags/":
        return .tag
      default:
        return .unknown
    }
  }
  
  func drawRefs()
  {
    var x: CGFloat = linesMargin + XTHistoryCellView.tokenMargin
    
    for ref in refs {
      guard let (refTypeName, displayRef) = ref.splitRefName()
      else { continue }
      
      let refRect = NSRect(x: x, y: -1,
                           width: XTRefToken.rectWidth(text: displayRef),
                           height: frame.size.height)
      
      XTRefToken.drawToken(refType: XTHistoryCellView.refType(refTypeName),
                           text: displayRef,
                           rect: refRect)
      x += refRect.size.width + XTHistoryCellView.tokenMargin
    }
  }
  
  func drawLines()
  {
    guard let entry = objectValue as? CommitEntry
    else { return }
    
    let bounds = self.bounds
    var topOffset: UInt = 0
    var bottomOffset: UInt = 0
    var dotOffset: UInt? = nil
    var dotColorIndex: UInt? = nil
    
    for connection in entry.connections {
      let path = NSBezierPath()
      
      if connection.parentOID == entry.commit.oid {
        if dotOffset == nil {
          dotOffset = topOffset
          dotColorIndex = connection.colorIndex
        }
        
        path.move(to: NSPoint(x: XTHistoryCellView.columnCenter(topOffset),
                              y: bounds.size.height))
        path.relativeLine(to: NSMakePoint(0, 0.5))
        path.line(to: NSPoint(x: XTHistoryCellView.columnCenter(dotOffset!),
                              y: bounds.size.height/2))
        topOffset += 1
      }
      else if connection.childOID == entry.commit.oid {
        if dotOffset == nil {
          dotOffset = topOffset
          dotColorIndex = connection.colorIndex
        }
        
        path.move(to: NSPoint(x: XTHistoryCellView.columnCenter(bottomOffset),
                              y: 0))
        path.relativeLine(to: NSMakePoint(0, -0.5))
        path.line(to: NSPoint(x: XTHistoryCellView.columnCenter(dotOffset!),
                              y: bounds.size.height/2))
        bottomOffset += 1
      }
      else {
        path.move(to: NSPoint(x: XTHistoryCellView.columnCenter(topOffset),
                              y: bounds.size.height))
        path.line(to: NSPoint(x: XTHistoryCellView.columnCenter(bottomOffset),
                              y: 0))
        topOffset += 1
        bottomOffset += 1
      }
      
      let colorIndex = Int(connection.colorIndex) %
                       XTHistoryCellView.lineColors.count
      let lineColor =  XTHistoryCellView.lineColors[colorIndex]
      
      path.lineJoinStyle = .roundLineJoinStyle
      NSColor.white.setStroke()
      path.lineWidth = 3.0
      path.stroke()
      lineColor.setStroke()
      path.lineWidth = 2.0
      path.stroke()
      
      if let dotOffset = dotOffset {
        let dotSize: CGFloat = 6.0
        let path = NSBezierPath(ovalIn:
            NSRect(x: XTHistoryCellView.columnCenter(dotOffset) - dotSize/2,
                   y: bounds.size.height/2 - dotSize/2,
                   width: dotSize, height: dotSize))
        let dotColorIndex = Int(dotColorIndex!) %
                            XTHistoryCellView.lineColors.count
        let baseDotColor = XTHistoryCellView.lineColors[dotColorIndex]
        let dotColor = baseDotColor.shadow(withLevel: 0.5) ?? baseDotColor
        
        NSColor.white.setStroke()
        path.lineWidth = 1.0
        path.stroke()
        dotColor.setFill()
        path.fill()
      }
    }
  }
  
}
