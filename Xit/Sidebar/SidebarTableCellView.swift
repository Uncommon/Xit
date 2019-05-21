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
  @IBOutlet weak var statusText: NSButton!
  @IBOutlet weak var prContanier: NSView!
  @IBOutlet weak var pullRequestButton: NSPopUpButton!
  @IBOutlet weak var prStatusImage: NSImageView!
  @IBOutlet weak var statusButton: NSButton!
  @IBOutlet weak var buttonContainer: NSView!
  @IBOutlet weak var missingImage: NSImageView!
  weak var item: SidebarItem?
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
