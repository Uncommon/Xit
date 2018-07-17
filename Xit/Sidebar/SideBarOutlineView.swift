import Foundation

@objc(XTSideBarOutlineView)
class SideBarOutlineView: ContextMenuOutlineView
{
  @IBOutlet public weak var controller: SidebarController!
  
  override func updateMenu(forItem item: Any)
  {
    switch item {
      case is RemoteBranchSidebarItem:
        menu = prepBranchMenu(controller.remoteBranchContextMenu, local: false)
      case is LocalBranchSidebarItem:
        menu = prepBranchMenu(controller.branchContextMenu, local: true)
      case is TagSidebarItem:
        menu = controller.tagContextMenu
      case is StashSidebarItem:
        menu = controller.stashContextMenu
      default:
        guard let groupItem = parent(forItem: item) as? SidebarItem
        else { break }
        
        if groupItem ==
           controller.sidebarDS.roots[XTGroupIndex.remotes.rawValue] {
          menu = controller.remoteContextMenu
        }
    }
  }
  
  func prepBranchMenu(_ menu: NSMenu, local: Bool) -> NSMenu
  {
    let renameIndex = menu.indexOfItem(
            withTarget: controller,
            andAction: #selector(SidebarController.renameBranch(_:)))
    
    if renameIndex != -1 {
      menu.items[renameIndex].isHidden = !local
    }
    return menu
  }
  
  override func mouseDown(with event: NSEvent)
  {
    let oldSelection = selectedRowIndexes
  
    super.mouseDown(with: event)
    
    let newSelection = selectedRowIndexes
    
    if oldSelection == newSelection,
       let xtDelegate = delegate as? XTOutlineViewDelegate {
      xtDelegate.outlineViewClickedSelectedRow(self)
    }
  }
}
