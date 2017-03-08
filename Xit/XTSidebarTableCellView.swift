import Cocoa

class XTSidebarTableCellView: NSTableCellView
{
  @IBOutlet weak var statusText: NSButton!
  @IBOutlet weak var statusImage: NSImageView!
  @IBOutlet weak var statusButton: NSButton!
  weak var item: XTSideBarItem?
}
