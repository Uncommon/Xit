import Cocoa
import SwiftUI

protocol PullRequestActionDelegate: AnyObject
{
  func viewPRWebPage(item: SidebarItem)
  func approvePR(item: SidebarItem)
  func unapprovePR(item: SidebarItem)
  func prNeedsWork(item: SidebarItem)
}

final class SidebarTableCellView: NSTableCellView
{
  @IBOutlet weak var statusText: WorkspaceStatusIndicator!
  @IBOutlet weak var prContanier: NSView!
  @IBOutlet weak var pullRequestButton: NSPopUpButton!
  @IBOutlet weak var prStatusImage: NSImageView!
  @IBOutlet weak var statusButton: NSButton!
  @IBOutlet weak var buttonContainer: NSView!
  @IBOutlet weak var missingImage: NSImageView!
  @IBOutlet weak var infoButton: NSButton!

  weak var item: SidebarItem?
  {
    didSet
    {
      guard let item = self.item,
            let textField = textField
      else { return }
      
      imageView?.image = item.icon
      textField.uiStringValue = item.displayTitle
      textField.isEditable = item.isEditable
      textField.isSelectable = item.isSelectable
      
      if let localItem = item as? LocalBranchSidebarItem,
         localItem.isCurrent {
        textField.setAccessibilityIdentifier(.Sidebar.currentBranch)
      }
      else {
        textField.setAccessibilityIdentifier(nil)
      }
    }
  }
  weak var prDelegate: (any PullRequestActionDelegate)?
  var rolloverArea: NSTrackingArea?
  var infoPopover: NSPopover?
  var infoAction: (() -> Void)?
  {
    didSet
    {
      infoPopover?.close()
      infoPopover = nil
      if infoAction != nil {
        enableRollover()
      }
      else {
        disableRollover()
      }
    }
  }

  func enableRollover()
  {
    let area = NSTrackingArea(rect: bounds,
                              options: [
                                .mouseEnteredAndExited,
                                .inVisibleRect,
                                .activeInKeyWindow,
                              ],
                              owner: self)

    rolloverArea = area
    addTrackingArea(area)
  }

  func disableRollover()
  {
    if let area = rolloverArea {
      removeTrackingArea(area)
      rolloverArea = nil
    }
  }

  func showInfoPopover(_ controller: NSViewController)
  {
    let popover = NSPopover()

    popover.contentViewController = controller
    popover.behavior = .transient
    popover.delegate = self
    popover.show(relativeTo: infoButton.bounds,
                      of: infoButton,
                      preferredEdge: .maxY)
    infoPopover = popover
  }

  func showInfoPopover<Content>(_ content: Content) where Content: View
  {
    showInfoPopover(NSHostingController(rootView: content))
  }

  override func awakeFromNib()
  {
    infoButton.target = self
    infoButton.action = #selector(Self.rolloverAction(_:))
  }

  @IBAction func rolloverAction(_ sender: Any?)
  {
    if let popover = infoPopover {
      popover.close()
      infoPopover = nil
    }
    else {
      infoAction?()
    }
  }

  override func viewDidMoveToSuperview()
  {
    infoPopover = nil
  }

  override func mouseEntered(with event: NSEvent)
  {
    if infoPopover == nil {
      infoButton.isHidden = false
    }
  }

  override func mouseExited(with event: NSEvent)
  {
    if infoPopover == nil {
      infoButton.isHidden = true
    }
  }
  
  @IBAction
  func viewPRWebPage(_ sender: AnyObject)
  {
    prDelegate?.viewPRWebPage(item: item!)
  }
  
  @IBAction
  func approvePR(_ sender: AnyObject)
  {
    prDelegate?.approvePR(item: item!)
  }
  
  @IBAction
  func unapprovePR(_ sender: AnyObject)
  {
    prDelegate?.unapprovePR(item: item!)
  }
  
  @IBAction
  func prNeedsWork(_ sender: AnyObject)
  {
    prDelegate?.prNeedsWork(item: item!)
  }

  static func item(for button: NSButton) -> SidebarItem?
  {
    var superview = button.superview
    
    while superview != nil {
      if let cellView = superview as? SidebarTableCellView {
        return cellView.item
      }
      superview = superview?.superview
    }
    
    return nil
  }
}

extension SidebarTableCellView: NSPopoverDelegate
{
  func popoverDidClose(_ notification: Notification)
  {
    infoPopover = nil
    infoButton.isHidden = true
  }
}
