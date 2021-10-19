import Foundation

/// View controller for history view, with the history list on top and
/// detail views below.
final class HistoryViewController: NSViewController
{
  @IBOutlet var tableController: HistoryTableController!
  @IBOutlet weak var historyTable: NSTableView!
  @IBOutlet var columnsMenu: NSMenu!

  var searchController: SearchAccessoryController!
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
  }
  
  override func viewDidAppear()
  {
    searchController =
      SearchAccessoryController(nibName: "SearchAccessoryController", bundle: nil)
    searchController.isHidden = true
    searchController.delegate = self
    view.window?.addTitlebarAccessoryViewController(searchController)
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
