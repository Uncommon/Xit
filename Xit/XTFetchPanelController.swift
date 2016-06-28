import Cocoa

public class XTFetchPanelController: NSWindowController {
  
  @IBOutlet var remotesPopup: NSPopUpButton?
  @IBOutlet var tagCheck: NSButton?
  @IBOutlet var pruneCheck: NSButton?
  
  var selectedRemote: NSString
  {
    get { return remotesPopup!.titleOfSelectedItem ?? "" }
    set { remotesPopup?.selectItemWithTitle(newValue as String) }
  }
  
  var downloadTags: Bool
  {
    get { return tagCheck?.intValue != 0 }
    set { tagCheck?.intValue = newValue ? 1 : 0 }
  }
  
  var pruneBranches: Bool
  {
    get { return pruneCheck?.intValue != 0 }
    set { pruneCheck?.intValue = newValue ? 1 : 0 }
  }
  
  var parentController : XTWindowController?
  {
    didSet
    {
      guard let menu = remotesPopup?.menu
      else { return }
      guard let repo = parentController?.xtDocument?.repository
        else { return }
      
      if let names = try? repo.remoteNames() {
        menu.removeAllItems()
        for name in names {
          menu.addItem(NSMenuItem(title: name, action: nil, keyEquivalent: ""))
        }
      }
    }
  }
  
  @IBAction func fetch(_: AnyObject)
  {
    self.parentController?.window?.endSheet(self.window!,
                                            returnCode: NSModalResponseOK)
  }

  @IBAction func cancel(_: AnyObject)
  {
    self.parentController?.window?.endSheet(self.window!,
                                            returnCode: NSModalResponseCancel)
  }
  
  public class func controller() -> XTFetchPanelController
  {
    return XTFetchPanelController(windowNibName: "XTFetchPanelController")
  }
}
