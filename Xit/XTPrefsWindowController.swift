import Cocoa

class XTPrefsWindowController: NSWindowController {
  
  @IBOutlet var accountsController: XTAccountsPrefsController!
  
  override func windowDidLoad() {
    super.windowDidLoad()
    
    // until other panes are implemented
    window!.contentViewController = accountsController
  }
  
  @IBAction func accountsSelected(sender: AnyObject)
  {
  }
  
  override func validateToolbarItem(item: NSToolbarItem) -> Bool
  {
    return item.itemIdentifier == "xit.prefs.accounts"
  }
}
