import Cocoa

class XTHistoryCellView: NSTableCellView {
  
  static let lineColors = [
      NSColor.blueColor(), NSColor.greenColor(), NSColor.redColor(),
      NSColor.brownColor(), NSColor.cyanColor(), NSColor.darkGrayColor(),
      NSColor.magentaColor(), NSColor.orangeColor(), NSColor.purpleColor(),
      NSColor(calibratedHue: 0.13, saturation: 0.08, brightness: 0.8, alpha: 1.0),
      NSColor.blackColor(), NSColor.lightGrayColor()]
  
  static let columnWidth: CGFloat = 8.0
  static let leftMargin: CGFloat = 4.0
  static let rightMargin: CGFloat = 4.0
  static let textMargin: CGFloat = 4.0

  static func columnCenter(index: UInt) -> CGFloat
  {
    return leftMargin + columnWidth * CGFloat(index) + columnWidth / 2
  }
  
  override func viewWillDraw()
  {
    super.viewWillDraw()
    
    guard let entry = objectValue as? CommitEntry,
          let textField = textField
    else { return }
    
    let incomingCount = entry.connections.reduce(0) { (count, connection) in
      return connection.parentSHA == entry.commit.SHA ? count + 1 : count
    }
    let outgoingCount = entry.connections.reduce(0) { (count, connection) in
      return connection.childSHA == entry.commit.SHA ? count + 1 : count
    }
    let throughCount = entry.connections.reduce(0) { (count, connection) in
      return (connection.parentSHA == entry.commit.SHA) ||
             (connection.childSHA == entry.commit.SHA)
             ? count : count + 1
    }
    let totalColumns = throughCount + max(incomingCount, outgoingCount)
    
    let textFrame = textField.frame
    let frame = self.frame
    
    var newFrame = textFrame
    
    newFrame.origin.x = XTHistoryCellView.leftMargin +
                        XTHistoryCellView.columnWidth * CGFloat(totalColumns) +
                        XTHistoryCellView.textMargin
    newFrame.size.width = frame.size.width - newFrame.origin.x -
                          XTHistoryCellView.rightMargin
    textField.frame = newFrame
  }
  
  override func drawRect(dirtyRect: NSRect)
  {
    super.drawRect(dirtyRect)
    
    guard let entry = objectValue as? CommitEntry
    else { return }
    
    let bounds = self.bounds
    var topOffset: UInt = 0
    var bottomOffset: UInt = 0
    var dotOffset: UInt? = nil
    var dotColorIndex: UInt? = nil
    
    for connection in entry.connections {
      let path = NSBezierPath()
      
      if connection.parentSHA == entry.commit.SHA {
        if dotOffset == nil {
          dotOffset = topOffset
          dotColorIndex = connection.colorIndex
        }
        
        path.moveToPoint(NSPoint(x: XTHistoryCellView.columnCenter(topOffset),
                                 y: bounds.size.height))
        path.relativeLineToPoint(NSMakePoint(0, -0.5))
        path.lineToPoint(NSPoint(x: XTHistoryCellView.columnCenter(dotOffset!),
                                 y: bounds.size.height/2))
        topOffset += 1
      }
      else if connection.childSHA == entry.commit.SHA {
        if dotOffset == nil {
          dotOffset = topOffset
          dotColorIndex = connection.colorIndex
        }
        
        path.moveToPoint(NSPoint(x: XTHistoryCellView.columnCenter(bottomOffset),
                                 y: 0))
        path.relativeLineToPoint(NSMakePoint(0, 0.5))
        path.lineToPoint(NSPoint(x: XTHistoryCellView.columnCenter(dotOffset!),
                                 y: bounds.size.height/2))
        bottomOffset += 1
      }
      else {
        path.moveToPoint(NSPoint(x: XTHistoryCellView.columnCenter(topOffset),
                                 y: bounds.size.height))
        path.lineToPoint(NSPoint(x: XTHistoryCellView.columnCenter(bottomOffset),
                                 y: 0))
        topOffset += 1
        bottomOffset += 1
      }
      
      let colorIndex = Int(connection.colorIndex) %
                       XTHistoryCellView.lineColors.count
      let lineColor =  XTHistoryCellView.lineColors[colorIndex]
      
      path.lineJoinStyle = .RoundLineJoinStyle
      NSColor.whiteColor().setStroke()
      path.lineWidth = 3.0
      path.stroke()
      lineColor.setStroke()
      path.lineWidth = 2.0
      path.stroke()
      
      if let dotOffset = dotOffset {
        let dotSize: CGFloat = 6.0
        let path = NSBezierPath(ovalInRect:
            NSRect(x: XTHistoryCellView.columnCenter(dotOffset) - dotSize/2,
                   y: bounds.size.height/2 - dotSize/2,
                   width: dotSize, height: dotSize))
        let dotColorIndex = Int(dotColorIndex!) %
                            XTHistoryCellView.lineColors.count
        let baseDotColor = XTHistoryCellView.lineColors[dotColorIndex]
        let dotColor = baseDotColor.shadowWithLevel(0.5) ?? baseDotColor
        
        NSColor.whiteColor().setStroke()
        path.lineWidth = 1.0
        path.stroke()
        dotColor.setFill()
        path.fill()
      }
    }
  }
  
}
