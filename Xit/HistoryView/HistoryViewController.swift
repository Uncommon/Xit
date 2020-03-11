import Foundation

/// View controller for history view, with the history list on top and
/// detail views below.
class HistoryViewController: NSViewController
{
  @IBOutlet weak var historyTable: NSTableView!
  @IBOutlet weak var mainSplitView: NSSplitView!
  @IBOutlet weak var tableController: HistoryTableController!
  @IBOutlet weak var scopeBar: NSView!
  @IBOutlet weak var scopeHeightConstraint: NSLayoutConstraint!
  @IBOutlet weak var searchTypePopup: NSPopUpButton!
  @IBOutlet weak var searchField: NSSearchField!
  @IBOutlet weak var searchButtons: NSSegmentedControl!
  
  private(set) var fileViewController: FileViewController!
  
  private var savedHistorySize: CGFloat?
  
  var historyHidden: Bool
  {
    return mainSplitView.subviewLength(0) == 0
  }
  
  var detailsHidden: Bool
  {
    return mainSplitView.subviewLength(1) == 0
  }
  
  override var nibName: NSNib.Name?
  {
    return .historyViewControllerNib
  }
  
  init()
  {
    super.init(nibName: .historyViewControllerNib, bundle: nil)
  }
  
  required init?(coder: NSCoder)
  {
    super.init(coder: coder)
  }
  
  override func loadView()
  {
    super.loadView()
  
    let lowerPane = mainSplitView.subviews[1]
    
    fileViewController = FileViewController(nibName: .fileViewControllerNib,
                                            bundle: nil)
    lowerPane.addSubview(fileViewController.view)
    fileViewController.view.setFrameSize(lowerPane.frame.size)
    
    var cellSpacing = historyTable.intercellSpacing
    
    cellSpacing.height = 0
    historyTable.intercellSpacing = cellSpacing
    
    setUpScopeBar()
  }
  
  func finishLoad(repository: XTRepository)
  {
    fileViewController.finishLoad(repository: repository)
    tableController.finishLoad()
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
  
  @IBAction
  func toggleHistory(_: Any?)
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
  
  @IBAction
  func toggleDetails(_: Any?)
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
  
  @IBAction
  func performFindPanelAction(_ sender: Any)
  {
    setScopeBarVisble(true)
  }
  
  @IBAction
  func closeScopeBar(_ sender: Any)
  {
    setScopeBarVisble(false)
  }
  
  @IBAction
  func changeSearchType(_ sender: Any)
  {
    
  }
}

extension HistoryViewController: NSSplitViewDelegate
{
  func splitView(_ splitView: NSSplitView,
                 shouldAdjustSizeOfSubview view: NSView) -> Bool
  {
    return view == splitView.subviews[0]
  }
}

extension HistoryViewController: NSTabViewDelegate
{
  func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?)
  {
    if let identifier = tabViewItem?.identifier as? String,
       identifier == "tree" {
      fileViewController.refreshPreview()
    }
  }
}
