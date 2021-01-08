import Foundation

/// View controller for history view, with the history list on top and
/// detail views below.
class HistoryViewController: NSViewController
{
  @IBOutlet var tableController: HistoryTableController!
  @IBOutlet weak var historyTable: NSTableView!
  @IBOutlet weak var scopeBar: NSView!
  @IBOutlet weak var scopeHeightConstraint: NSLayoutConstraint!
  @IBOutlet weak var searchTypePopup: NSPopUpButton!
  @IBOutlet weak var searchField: NSSearchField!
  @IBOutlet weak var searchButtons: NSSegmentedControl!
  @IBOutlet var columnsMenu: NSMenu!

  weak var splitController: NSSplitViewController!
  var fileViewController: FileViewController!

  var historyHidden: Bool
  { splitController.splitViewItems[0].isCollapsed }
  
  var detailsHidden: Bool
  { splitController.splitViewItems[1].isCollapsed }

  override func loadView()
  {
    super.loadView()
  
    var cellSpacing = historyTable.intercellSpacing
    
    cellSpacing.height = 0
    historyTable.intercellSpacing = cellSpacing
    
    setUpScopeBar()
  }
  
  func finishLoad(repository: XTRepository)
  {
    fileViewController.finishLoad(repository: repository)
    tableController.finishLoad(repository: repository)
  }
  
  func reload()
  {
    (historyTable.dataSource as? HistoryTableController)?.reload()
    fileViewController.reload()
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
