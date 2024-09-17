import Foundation
import Cocoa
import SwiftUI

extension NSView
{
  /// Follows the superview chain and returns the highest ancestor.
  var firstAncestor: NSView?
  {
    var ancestor = superview
    
    while ancestor?.superview != nil {
      ancestor = ancestor?.superview
    }
    return ancestor
  }
  
  /// Returns the window for the view's first ancestor. For example, if a view
  /// is in a hidden tab, its own `window` will be `null`, but this will still
  /// return the real window.
  var ancestorWindow: NSWindow?
  { firstAncestor?.window }
}

extension NSAlert
{
  static func confirm(message: UIString, infoString: UIString? = nil,
                      actionName: UIString,
                      isDestructive: Bool = false,
                      parentWindow: NSWindow,
                      action: @escaping () -> Void)
  {
    let alert = NSAlert()
    
    alert.messageString = message
    if let info = infoString {
      alert.informativeString = info
    }
    alert.addButton(withString: actionName)
    alert.addButton(withString: .cancel)
    alert.buttons[0].hasDestructiveAction = isDestructive
    alert.beginSheetModal(for: parentWindow) {
      (response) in
      if response == .alertFirstButtonReturn {
        action()
      }
    }
  }
  
  static func showMessage(window: NSWindow? = nil, message: UIString,
                          infoString: UIString? = nil)
  {
    let alert = NSAlert()
    
    alert.messageString = message
    if let infoString = infoString {
      alert.informativeString = infoString
    }
    if let window = window {
      alert.alertStyle = .critical // appear over existing sheet
      alert.beginSheetModal(for: window)
    }
    else {
      alert.runModal()
    }
  }
}

extension NSControl
{
  /// The intValue property interpreted as a Bool.
  var boolValue: Bool
  {
    get { intValue != 0 }
    set { intValue = newValue ? 1 : 0 }
  }
}

extension NSButton: @retroactive NSValidatedUserInterfaceItem {}

extension NSTextField
{
  var isTruncated: Bool
  {
    guard let expansionRect = cell?.expansionFrame(withFrame: frame, in: self)
    else { return false }
    
    return expansionRect != NSRect.zero
  }
}

extension NSHostingController
{
  convenience init(@ViewBuilder _ viewBuilder: () -> Content)
  {
    self.init(rootView: viewBuilder())
  }
}

extension NSTabView
{
  func tabViewItem(withIdentifier identifier: Any) -> NSTabViewItem?
  {
    let index = indexOfTabViewItem(withIdentifier: identifier)
    guard index != NSNotFound
    else { return nil }
    
    return tabViewItem(at: index)
  }
}

extension NSTableView
{
  func columnObject(withIdentifier id: NSUserInterfaceItemIdentifier)
    -> NSTableColumn?
  {
    let index = column(withIdentifier: id)
    guard index >= 0
    else { return nil }

    return tableColumns[index]
  }

  /// Resizes the first column so the table view fits exactly within its
  /// enclosing clip view.
  func sizeFirstColumnToFit()
  {
    guard let superview = self.superview,
          let firstColumn = tableColumns.first
    else { return }
    let width = superview.frame.width
    let totalColumnWidth = tableColumns.reduce(0) {
      (total, column) in
      total + (column.isHidden ? 0 : column.width)
    }

    tableColumns[0].width = max(firstColumn.minWidth,
                                firstColumn.width + width - totalColumnWidth)
  }

  /// Returns a set of all visible row indexes
  func visibleRows() -> IndexSet
  {
    return IndexSet(integersIn: Range(rows(in: visibleRect)) ?? 0..<0)
  }
  
  func scrollRowToCenter(_ row: Int)
  {
    guard let clipView = superview as? NSClipView
    else { return }
    let rowRect = rect(ofRow: row)
    var scrollOrigin = rowRect.origin

    let tableHalfHeight = clipView.frame.height * 0.5
    let rowRectHalfHeight = rowRect.height * 0.5

    scrollOrigin.y = (scrollOrigin.y - tableHalfHeight) + rowRectHalfHeight
    clipView.animator().setBoundsOrigin(scrollOrigin)
  }
}

extension NSSplitView
{
  func animate(position: CGFloat, ofDividerAtIndex index: Int)
  {
    let targetView = subviews[index]
    var endFrame = targetView.frame
    
    if isVertical {
      endFrame.size.width = position
    }
    else {
      endFrame.size.height = position
    }
    
    let windowResize: [NSViewAnimation.Key: Any] = [
      .target: targetView,
      .endFrame: endFrame ]
    let animation = NSViewAnimation(viewAnimations: [windowResize])
    
    animation.animationBlockingMode = .blocking
    animation.duration = 0.2
    animation.start()
  }
  
  // Workaround because isSubviewCollapsed doesn't return the expected value
  // while a splitter is being dragged
  /// Returns the width or height, as appropriate, of the given subview.
  func subviewLength(_ index: Int) -> CGFloat
  {
    guard index <= subviews.count
    else { return 0 }
    let size = subviews[index].frame.size
    
    return isVertical ? size.width : size.height
  }
}

extension NSSplitViewItem
{
  func toggleCollapsed()
  {
    isCollapsed = !isCollapsed
  }
}

extension NSValidatedUserInterfaceItem
{
  var isContextMenuItem: Bool
  {
    guard let item = self as? NSMenuItem
    else { return false }
    
    return item.parent == nil
  }
}
