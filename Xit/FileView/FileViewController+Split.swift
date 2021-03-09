import Foundation

extension FileViewController: NSSplitViewDelegate
{
  static let minHeaderHeight: CGFloat = 45
  static let minDetailHeight: CGFloat = 60

  var maxHeaderHeight: CGFloat
  {
    headerSplitView.bounds.height - Self.minDetailHeight
  }

  public func splitView(_ splitView: NSSplitView,
                        shouldAdjustSizeOfSubview view: NSView) -> Bool
  {
    // Supposedly this can be done with holding priorities
    // but that's not working.
    switch splitView {
      case headerSplitView:
        return view != headerTabView
      case fileSplitView:
        return view != fileListTabView
      default:
        return true
    }
  }

  public func splitView(_ splitView: NSSplitView,
                        constrainMinCoordinate proposedMinimumPosition: CGFloat,
                        ofSubviewAt dividerIndex: Int) -> CGFloat
  {
    switch splitView {
      case headerSplitView:
        return Self.minHeaderHeight
      default:
        return proposedMinimumPosition
    }
  }

  public func splitView(_ splitView: NSSplitView,
                        constrainMaxCoordinate proposedMaximumPosition: CGFloat,
                        ofSubviewAt dividerIndex: Int) -> CGFloat
  {
    switch splitView {
      case headerSplitView:
        return maxHeaderHeight
      default:
        return proposedMaximumPosition
    }
  }

  public func splitViewDidResizeSubviews(_ notification: Notification)
  {
    guard !resizeRecursing,
          let splitView = notification.object as? NSSplitView,
          splitView == headerSplitView
    else { return }
    let headerHeight = splitView.arrangedSubviews[0].bounds.height

    resizeRecursing = true
    defer {
      resizeRecursing = false
    }

    if headerHeight < Self.minHeaderHeight {
      splitView.setPosition(Self.minHeaderHeight, ofDividerAt: 0)
    }
    else {
      let maxHeaderHeight = self.maxHeaderHeight

      if headerHeight > maxHeaderHeight {
        splitView.setPosition(maxHeaderHeight, ofDividerAt: 0)
      }
    }
  }
}
