import Cocoa

class SidebarTableCellView: NSTableCellView
{
  @IBOutlet weak var statusText: NSButton!
  @IBOutlet weak var statusImage: NSImageView!
  @IBOutlet weak var statusButton: NSButton!
  @IBOutlet weak var buttonContainer: NSView!
  @IBOutlet weak var missingImage: NSImageView!
  weak var item: SidebarItem?
}
