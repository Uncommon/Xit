import Cocoa

class FileListView: ContextMenuOutlineView
{
  @IBOutlet var stagingMenu: NSMenu!
  @IBOutlet var commitMenu: NSMenu!
  
  override func updateMenu(forItem item: Any)
  {
    let controller = window?.windowController as! XTWindowController
    
    if controller.selection?.canCommit ?? false {
      menu = stagingMenu
    }
    else {
      menu = commitMenu
    }
  }
}
