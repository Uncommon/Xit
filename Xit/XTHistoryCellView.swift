import Cocoa

class XTHistoryCellView: NSTableCellView {
  
  static let lineColors = [
      NSColor.blueColor(), NSColor.greenColor(), NSColor.redColor(),
      NSColor.brownColor(), NSColor.cyanColor(), NSColor.darkGrayColor(),
      NSColor.magentaColor(), NSColor.orangeColor(), NSColor.purpleColor(),
      NSColor(calibratedHue: 0.13, saturation: 0.08, brightness: 0.8, alpha: 1.0),
      NSColor.blackColor(), NSColor.lightGrayColor()]
  
  func columnCenter(index: UInt) -> CGFloat
  {
    let columnWidth: CGFloat = 8.0
    
    return columnWidth * CGFloat(index) + columnWidth / 2
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
        
        path.moveToPoint(NSMakePoint(columnCenter(topOffset),
                                     bounds.size.height))
        path.relativeLineToPoint(NSMakePoint(0, -0.5))
        path.lineToPoint(NSMakePoint(columnCenter(dotOffset!),
                                     bounds.size.height/2))
        topOffset += 1
      }
      else if connection.childSHA == entry.commit.SHA {
        if dotOffset == nil {
          dotOffset = topOffset
          dotColorIndex = connection.colorIndex
        }
        
        path.moveToPoint(NSMakePoint(columnCenter(bottomOffset), 0))
        path.relativeLineToPoint(NSMakePoint(0, 0.5))
        path.lineToPoint(NSMakePoint(columnCenter(dotOffset!),
                                     bounds.size.height/2))
        bottomOffset += 1
      }
      else {
        path.moveToPoint(NSMakePoint(columnCenter(topOffset), bounds.size.height))
        path.lineToPoint(NSMakePoint(columnCenter(bottomOffset), 0))
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
            NSMakeRect(columnCenter(dotOffset) - dotSize/2,
                       bounds.size.height/2 - dotSize/2,
                       dotSize, dotSize))
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
