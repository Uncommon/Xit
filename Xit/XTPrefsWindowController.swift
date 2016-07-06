import Cocoa

class XTPrefsWindowController: NSWindowController {
  
  static let sharedPrefsController =
      XTPrefsWindowController(windowNibName: "XTPrefsWindowController")
  
  @IBOutlet var accountsController: XTAccountsPrefsController!
  
  override func windowDidLoad()
  {
    super.windowDidLoad()
    
    // until other panes are implemented
    window!.contentViewController = accountsController
    
    window!.toolbar!.selectedItemIdentifier = "xit.prefs.accounts"
  }
  
  func windowDidResignKey(notification: NSNotification)
  {
    accountsController.saveAccounts()
  }
  
  @IBAction func accountsSelected(sender: AnyObject)
  {
  }
  
  override func validateToolbarItem(item: NSToolbarItem) -> Bool
  {
    return item.itemIdentifier == "xit.prefs.accounts"
  }
}
