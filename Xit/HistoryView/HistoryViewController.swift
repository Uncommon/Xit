import Foundation
import SwiftUI
import Cocoa

/// View controller for history view, with the history list on top and
/// detail views below.
final class HistoryViewController: NSViewController
{
  @IBOutlet var tableController: HistoryTableController!
  @IBOutlet weak var historyTable: NSTableView!

  var searchController: HostingTitlebarController<HistorySearchBar>!
  weak var splitController: NSSplitViewController!
  weak var fileViewController: FileViewController!

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
    searchController = .init(rootView: .init(searchUp: {
      [weak self] in
      guard let self = self else { return }
      self.search(for: $0,
                  type: $1,
                  direction: .up)
    }, searchDown: {
      [weak self] in
      guard let self = self else { return }
      self.search(for: $0,
                  type: $1,
                  direction: .down)
    }))
    searchController.isHidden = true
    view.window?.addTitlebarAccessoryViewController(searchController)
  }
  
  func finishLoad(repository: any FullRepository)
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
