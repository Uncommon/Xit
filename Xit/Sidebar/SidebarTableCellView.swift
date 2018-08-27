import Cocoa

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
  weak var dataSource: SideBarDataSource?
  
  @IBAction func viewPRWebPage(_ sender: AnyObject)
  {
    dataSource?.viewPRWebPage(item: item!)
  }
  
  @IBAction func approvePR(_ sender: AnyObject)
  {
    dataSource?.approvePR(item: item!)
  }
  
  @IBAction func unapprovePR(_ sender: AnyObject)
  {
    dataSource?.unapprovePR(item: item!)
  }
  
  @IBAction func prNeedsWork(_ sender: AnyObject)
  {
    dataSource?.prNeedsWork(item: item!)
  }
}
