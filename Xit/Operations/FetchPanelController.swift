import Cocoa

final class FetchPanelController: SheetController
{
  @IBOutlet var remotesPopup: NSPopUpButton?
  @IBOutlet var tagCheck: NSButton?
  @IBOutlet var pruneCheck: NSButton?
  
  var selectedRemote: String
  {
    get { remotesPopup!.titleOfSelectedItem ?? "" }
    set { remotesPopup?.selectItem(withTitle: newValue) }
  }
  
  var downloadTags: Bool
  {
    get { tagCheck?.intValue != 0 }
    set { tagCheck?.intValue = newValue ? 1 : 0 }
  }
  
  var pruneBranches: Bool
  {
    get { pruneCheck?.intValue != 0 }
    set { pruneCheck?.intValue = newValue ? 1 : 0 }
  }
  
  var parentController: XTWindowController?
  {
    didSet
    {
      guard let menu = remotesPopup?.menu,
            let repo = parentController?.repoDocument?.repository
      else { return }
      
      menu.items = repo.remoteNames().map {
        NSMenuItem(title: $0, action: nil, keyEquivalent: "")
      }
    }
  }
}
