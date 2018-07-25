import Foundation

/// View controller for history view, with the history list on top and
/// detail views below.
class XTHistoryViewController: NSViewController
{
  @IBOutlet weak var historyTable: NSTableView!
  @IBOutlet weak var mainSplitView: NSSplitView!
  @IBOutlet weak var tableController: HistoryTableController!
  @IBOutlet weak var scopeBar: NSView!
  
  private(set) var fileViewController: FileViewController!
  
  private var savedHistorySize: CGFloat?
  
  enum NibName
  {
    static let historyViewController: NSNib.Name = ◊"XTHistoryViewController"
    static let fileViewController: NSNib.Name = ◊"FileViewController"
  }
  
  weak var repo: XTRepository!
  
  var historyHidden: Bool
  {
    return mainSplitView.isSubviewCollapsed(mainSplitView.subviews[0])
  }
  
  var detailsHidden: Bool
  {
    return mainSplitView.isSubviewCollapsed(mainSplitView.subviews[1])
  }
  
  override var nibName: NSNib.Name?
  {
    return NibName.historyViewController
  }
  
  init()
  {
    super.init(nibName: NibName.historyViewController, bundle: nil)
  }
  
  // For testing
  private init(repository: XTRepository)
  {
    repo = repository
    super.init(coder: NSCoder())!
  }
  
  required init?(coder: NSCoder)
  {
    super.init(coder: coder)
  }
  
  override func loadView()
  {
    super.loadView()
  
    let lowerPane = mainSplitView.subviews[1]
    
    fileViewController = FileViewController(nibName: NibName.fileViewController,
                                            bundle: nil)
    lowerPane.addSubview(fileViewController.view)
    fileViewController.view.setFrameSize(lowerPane.frame.size)
    
    var cellSpacing = historyTable.intercellSpacing
    
    cellSpacing.height = 0
    historyTable.intercellSpacing = cellSpacing
  }
  
  func finishLoad(repository: XTRepository)
  {
    fileViewController.finishLoad(repository: repository)
    tableController.repository = repository
  }
  
  func reload()
  {
    (historyTable.dataSource as? HistoryTableController)?.reload()
    fileViewController.reload()
  }
  
  func saveHistorySize()
  {
    let historySize = mainSplitView.subviews[0].bounds.size
    
    savedHistorySize = mainSplitView.isVertical ? historySize.width
                                                : historySize.height
  }
  
  @IBAction func toggleHistory(_: Any?)
  {
    if historyHidden {
      // Go back to the un-collapsed size.
      if let size = savedHistorySize {
        mainSplitView.setPosition(size, ofDividerAt: 0)
        mainSplitView.subviews[0].isHidden = false
      }
    }
    else {
      if detailsHidden {
        // Details pane is collapsed, so swap them.
        let minSize = mainSplitView.minPossiblePositionOfDivider(at: 0)
        
        mainSplitView.setPosition(minSize, ofDividerAt: 0)
        mainSplitView.subviews[1].isHidden = false
      }
      else {
        // Both panes are showing, so just collapse history.
        let newSize = mainSplitView.minPossiblePositionOfDivider(at: 0)
        
        saveHistorySize()
        mainSplitView.setPosition(newSize, ofDividerAt: 0)
      }
      mainSplitView.subviews[0].isHidden = true
    }
  }
  
  @IBAction func toggleDetails(_: Any?)
  {
    if detailsHidden {
      // Go back to the un-collapsed size.
      if let size = savedHistorySize {
        mainSplitView.setPosition(size, ofDividerAt: 0)
        mainSplitView.subviews[1].isHidden = false
      }
    }
    else {
      if historyHidden {
        // History pane is collapsed, so swap them.
        let maxSize = mainSplitView.maxPossiblePositionOfDivider(at: 0)
        
        mainSplitView.setPosition(maxSize, ofDividerAt: 0)
        mainSplitView.subviews[0].isHidden = false
      }
      else {
        // Both panes are showing, so just collapse details.
        // Save the history pane size in both cases because it's the same divider
        // restored to the same position in both cases.
        let newSize = mainSplitView.maxPossiblePositionOfDivider(at: 0)
        
        saveHistorySize()
        mainSplitView.setPosition(newSize, ofDividerAt: 0)
      }
      mainSplitView.subviews[1].isHidden = true
    }
  }
  
  @IBAction func performFindPanelAction(_ sender: Any)
  {
    setScopeBarVisble(true)
  }
  
  @IBAction func closeScopeBar(_ sender: Any)
  {
    setScopeBarVisble(false)
  }
  
  func setScopeBarVisble(_ visible: Bool)
  {
    NSAnimationContext.runAnimationGroup({
      (context) in
      context.duration = 0.25
      context.allowsImplicitAnimation = true
      scopeBar.isHidden = !visible
      mainSplitView.layoutSubtreeIfNeeded()
    }, completionHandler: nil)
  }
}

extension XTHistoryViewController: NSSplitViewDelegate
{
  func splitView(_ splitView: NSSplitView,
                 shouldAdjustSizeOfSubview view: NSView) -> Bool
  {
    return view != splitView.subviews[0]
  }
}

extension XTHistoryViewController: NSTabViewDelegate
{
  func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?)
  {
    if let identifier = tabViewItem?.identifier as? String,
       identifier == "tree" {
      fileViewController.refreshPreview()
    }
  }
}
