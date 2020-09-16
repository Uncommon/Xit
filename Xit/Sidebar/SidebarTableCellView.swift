import Cocoa

protocol PullRequestActionDelegate: AnyObject
{
  func viewPRWebPage(item: SidebarItem)
  func approvePR(item: SidebarItem)
  func unapprovePR(item: SidebarItem)
  func prNeedsWork(item: SidebarItem)
}

class SidebarTableCellView: NSTableCellView
{
  @IBOutlet weak var statusText: WorkspaceStatusIndicator!
  @IBOutlet weak var prContanier: NSView!
  @IBOutlet weak var pullRequestButton: NSPopUpButton!
  @IBOutlet weak var prStatusImage: NSImageView!
  @IBOutlet weak var statusButton: NSButton!
  @IBOutlet weak var buttonContainer: NSView!
  @IBOutlet weak var missingImage: NSImageView!
  weak var item: SidebarItem?
  {
    didSet
    {
      guard let item = self.item,
            let textField = textField
      else { return }
      
      imageView?.image = item.icon
      textField.uiStringValue = item.displayTitle
      textField.isEditable = item.editable
      textField.isSelectable = item.isSelectable
    }
  }
  weak var prDelegate: PullRequestActionDelegate?
  
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
