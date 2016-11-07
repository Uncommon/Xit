import Cocoa

class XTSidebarTableCellView: NSTableCellView
{
  @IBOutlet weak var statusText: NSButton!
  @IBOutlet weak var statusImage: NSImageView!
  weak var item: XTSideBarItem?
}
