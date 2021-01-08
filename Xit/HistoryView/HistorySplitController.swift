import Cocoa

class HistorySplitController: NSSplitViewController
{
  var historyController: HistoryViewController!

  private var savedHistorySize: CGFloat?

  override func awakeFromNib()
  {
    let fileController = FileViewController(nibName: .fileViewControllerNib,
                                            bundle: nil)

    historyController = splitViewItems[0].viewController as? HistoryViewController
    historyController.splitController = self
    historyController.fileViewController = fileController

    // TODO: Convert FileViewController.xib to a storyboard that can be loaded
    // by reference.
    removeSplitViewItem(splitViewItems[1])
    addSplitViewItem(NSSplitViewItem(viewController: fileController))
  }

  @IBAction
  func toggleHistory(_: Any?)
  {
    splitViewItems[0].toggleCollapsed()
    /*
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
    */
  }

  @IBAction
  func toggleDetails(_: Any?)
  {
    splitViewItems[1].toggleCollapsed()
    /*
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
    */
  }

  func saveHistorySize()
  {
    let historySize = splitView.subviews[0].bounds.size

    savedHistorySize = splitView.isVertical ? historySize.width
                                            : historySize.height
  }

}
