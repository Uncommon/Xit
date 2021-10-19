import Cocoa

final class HistorySplitController: NSSplitViewController
{
  var historyController: HistoryViewController!

  private var savedHistorySize: CGFloat?
  
  var historyHidden: Bool { splitViewItems[0].isCollapsed }
  var detailsHidden: Bool { splitViewItems[1].isCollapsed }

  override func viewDidLoad()
  {
    super.viewDidLoad()

    historyController = splitViewItems[0].viewController as? HistoryViewController
    historyController.splitController = self

    // TODO: Convert FileViewController.xib to a storyboard that can be loaded
    // by reference.
    let fileController = FileViewController(nibName: .fileViewControllerNib,
                                            bundle: nil)
    let fileViewItem = NSSplitViewItem(viewController: fileController)

    historyController.fileViewController = fileController
    fileViewItem.canCollapse = true
    fileViewItem.minimumThickness = FileViewController.minDetailHeight +
                                    FileViewController.minHeaderHeight
    fileViewItem.holdingPriority = .init(NSLayoutConstraint.Priority
                                         .dragThatCannotResizeWindow.rawValue - 1)
    insertSplitViewItem(fileViewItem, at: 1)
    splitViewItems[0].minimumThickness = 60

    // Thick divider crashes if there is only one split item
    splitView.dividerStyle = .thick
  }

  @IBAction
  func toggleHistory(_: Any?)
  {
    if historyHidden {
      // Go back to the un-collapsed size.
      if let size = savedHistorySize {
        splitView.setPosition(size, ofDividerAt: 0)
        splitView.subviews[0].isHidden = false
      }
    }
    else {
      if detailsHidden {
        // Details pane is collapsed, so swap them.
        let minSize = splitView.minPossiblePositionOfDivider(at: 0)

        splitView.setPosition(minSize, ofDividerAt: 0)
        splitView.subviews[1].isHidden = false
      }
      else {
        // Both panes are showing, so just collapse history.
        let newSize = splitView.minPossiblePositionOfDivider(at: 0)

        saveHistorySize()
        splitView.setPosition(newSize, ofDividerAt: 0)
      }
      splitView.subviews[0].isHidden = true
    }
  }

  @IBAction
  func toggleDetails(_: Any?)
  {
    if detailsHidden {
      // Go back to the un-collapsed size.
      if let size = savedHistorySize {
        splitView.setPosition(size, ofDividerAt: 0)
        splitView.subviews[1].isHidden = false
      }
      historyController.fileViewController.restoreSplit()
    }
    else {
      if historyHidden {
        // History pane is collapsed, so swap them.
        let maxSize = splitView.maxPossiblePositionOfDivider(at: 0)

        historyController.fileViewController.saveSplit()
        splitView.setPosition(maxSize, ofDividerAt: 0)
        splitView.subviews[0].isHidden = false
      }
      else {
        // Both panes are showing, so just collapse details.
        // Save the history pane size in both cases because it's the same divider
        // restored to the same position in both cases.
        let newSize = splitView.maxPossiblePositionOfDivider(at: 0)

        saveHistorySize()
        historyController.fileViewController.saveSplit()
        splitView.setPosition(newSize, ofDividerAt: 0)
      }
      splitView.subviews[1].isHidden = true
    }
  }

  func saveHistorySize()
  {
    let historySize = splitView.subviews[0].bounds.size

    savedHistorySize = splitView.isVertical ? historySize.width
                                            : historySize.height
  }
}
