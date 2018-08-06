import Cocoa

/// Cell view that draws the graph lines next to the text.
class HistoryCellView: NSTableCellView
{
  private var entry: CommitEntry!
  private var currentBranch: String?
  private var refs = [String]()
  
  static let lineColors = [
      NSColor.systemBlue, NSColor.systemGreen, NSColor.systemRed,
      NSColor.systemBrown, NSColor.cyan, NSColor.darkGray,
      NSColor.magenta, NSColor.systemOrange, NSColor.systemPurple,
      // Regular yellow is too light
      NSColor(calibratedHue: 0.13, saturation: 0.08, brightness: 0.8, alpha: 1.0),
      NSColor.textColor, NSColor.lightGray]
  
  enum Widths
  {
    static let line: CGFloat = 2.0
    static let column: CGFloat = 8.0
  }
  
  enum Margins
  {
    static let left: CGFloat = 4.0
    static let right: CGFloat = 4.0
    static let text: CGFloat = 4.0
    static let token: CGFloat = 4.0
  }
  
  @IBOutlet weak var stackView: NSStackView!
  @IBOutlet var stackViewInset: NSLayoutConstraint!

  override var backgroundStyle: NSView.BackgroundStyle
  {
    didSet
    {
      let color: NSColor
      
      switch backgroundStyle {
        
        case .normal:
          color = .textColor
        case .emphasized:
          color = .alternateSelectedControlTextColor
        default:
          color = .textColor
      }
      textField?.textColor = color
    }
  }
  
  func configure(entry: CommitEntry, repository: Branching & CommitReferencing)
  {
    currentBranch = repository.currentBranch
    refs = repository.refs(at: entry.commit.sha)
    textField?.stringValue = entry.commit.message ?? "(no message)"
    self.entry = entry
    
    var views = refs.reversed().map {
      (ref) -> NSView in
      let view = RefTokenView()
      
      if let (_, name) = ref.splitRefName() {
        view.text = name
        view.type = RefType(refName: ref, currentBranch: currentBranch ?? "")
      }
      return view
    }
    
    views.append(textField!)
    stackView.setViews(views, in: .leading)
    stackView.needsLayout = true
    needsUpdateConstraints = true
  }
  
  /// Finds the center of the given column.
  static func columnCenter(_ index: UInt) -> CGFloat
  {
    return Margins.left + Widths.column * CGFloat(index) + Widths.column / 2
  }
  
  /// Moves the text field out of the way of the lines and refs.
  override func updateConstraints()
  {
    let totalColumns = entry.lines.reduce(0) { (oldMax, line) -> UInt in
      max(oldMax, line.parentIndex ?? 0, line.childIndex ?? 0)
    }
    let linesMargin = Margins.left + CGFloat(totalColumns + 1) * Widths.column
    
    stackViewInset.constant = linesMargin + Margins.text
    super.updateConstraints()
  }
  
  /// Draws the graph lines in the view.
  override func draw(_ dirtyRect: NSRect)
  {
    super.draw(dirtyRect)
    
    drawLines()
  }
  
  /// Calculates an offset for graph line corners to avoid awkward breaks
  func cornerOffset(_ offset1: UInt, _ offset2: UInt) -> CGFloat
  {
    let pathOffset = abs(Int(offset1) - Int(offset2))
    let height = Double(pathOffset) * 0.25
    
    return min(CGFloat(height), Widths.line)
  }
  
  func path(for line: HistoryLine) -> NSBezierPath?
  {
    guard let dotOffset = entry.dotOffset
    else { return nil }
    let path = NSBezierPath()
    
    switch (line.parentIndex, line.childIndex) {
      
      case (nil, let childIndex?):
        path.move(to: NSPoint(x: HistoryCellView.columnCenter(childIndex),
                              y: bounds.size.height))
        path.relativeLine(to: NSPoint(x: 0, y: -cornerOffset(dotOffset,
                                                             childIndex)))
        path.line(to: NSPoint(x: HistoryCellView.columnCenter(dotOffset),
                              y: bounds.size.height/2))
      
      case (let parentIndex?, nil):
        path.move(to: NSPoint(x: HistoryCellView.columnCenter(parentIndex),
                              y: 0))
        path.relativeLine(to: NSPoint(x: 0, y: cornerOffset(dotOffset,
                                                            parentIndex)))
        path.line(to: NSPoint(x: HistoryCellView.columnCenter(dotOffset),
                              y: bounds.size.height/2))
      
      case (let parentIndex?, let childIndex?):
        path.move(to: NSPoint(x: HistoryCellView.columnCenter(childIndex),
                              y: bounds.size.height))
        if parentIndex != childIndex {
          let cornerOffset = self.cornerOffset(childIndex, parentIndex)
          
          path.relativeLine(to: NSPoint(x: 0, y: -cornerOffset))
          path.line(to: NSPoint(x: HistoryCellView.columnCenter(parentIndex),
                                y: cornerOffset))
        }
        path.line(to: NSPoint(x: HistoryCellView.columnCenter(parentIndex),
                              y: 0))
      
      case (nil, nil):
        return nil
    }
    return path
  }
  
  func drawLines()
  {
    guard let dotOffset = entry.dotOffset,
          let dotColorIndex = entry.dotColorIndex
    else { return }
    
    for line in entry.lines {
      guard let path = path(for: line)
      else { continue }
      
      let colorIndex = Int(line.colorIndex) %
                       HistoryCellView.lineColors.count
      let lineColor =  HistoryCellView.lineColors[colorIndex]
      
      path.lineJoinStyle = .roundLineJoinStyle
      if line.parentIndex != line.childIndex {
        NSColor.textBackgroundColor.setStroke()
        path.lineWidth = Widths.line + 1.0
        path.stroke()
      }
      lineColor.setStroke()
      path.lineWidth = Widths.line
      path.stroke()
      
      let dotSize: CGFloat = 6.0
      let dotPath = NSBezierPath(ovalIn:
              NSRect(x: HistoryCellView.columnCenter(dotOffset) - dotSize/2,
                     y: bounds.size.height/2 - dotSize/2,
                     width: dotSize, height: dotSize))
      let dotColorIndex = Int(dotColorIndex) %
                          HistoryCellView.lineColors.count
      let baseDotColor = HistoryCellView.lineColors[dotColorIndex]
      let dotColor = baseDotColor.blended(withFraction: 0.5,
                                          of: NSColor.textColor) ?? baseDotColor
      
      NSColor.textBackgroundColor.setStroke()
      dotPath.lineWidth = 1.0
      dotPath.stroke()
      dotColor.setFill()
      dotPath.fill()
    }
  }
}
