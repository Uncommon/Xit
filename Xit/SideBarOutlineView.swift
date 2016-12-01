import Foundation

class SideBarOutlineView: NSOutlineView
{
  @IBOutlet public weak var controller: XTSidebarController!
  public private(set) var contextMenuRow: Int? = nil
  
  override func rightMouseDown(with event: NSEvent)
  {
    defer {
      super.rightMouseDown(with: event)
      contextMenuRow = nil
    }
  
    let localPoint = convert(event.locationInWindow, from: nil)
    let clickedRow = row(at: localPoint)
    guard let item = self.item(atRow: clickedRow)
    else { return }
    
    contextMenuRow = clickedRow
    switch item {
      case is XTRemoteBranchItem:
        menu = prepBranchMenu(local: false)
      case is XTLocalBranchItem:
        menu = prepBranchMenu(local: true)
      case is XTTagItem:
        menu = controller.tagContextMenu
      case is XTStashItem:
        menu = controller.stashContextMenu
      default:
        guard let groupItem = parent(forItem: item) as? XTSideBarItem
        else { break }
        
        if groupItem ==
           controller.sidebarDS.roots[XTGroupIndex.remotes.rawValue] {
          menu = controller.remoteContextMenu
        }
    }
  }
  
  func prepBranchMenu(local: Bool) -> NSMenu
  {
    let menu = controller.branchContextMenu!
    let renameIndex = menu.indexOfItem(
            withTarget: controller,
            andAction: #selector(XTSidebarController.renameBranch(_:)))
    
    if renameIndex != -1 {
      menu.items[renameIndex].isHidden = !local
    }
    return menu
  }
}
