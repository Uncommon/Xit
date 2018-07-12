import Foundation

@objc(XTSideBarOutlineView)
class SideBarOutlineView: ContextMenuOutlineView
{
  @IBOutlet public weak var controller: XTSidebarController!
  
  override func updateMenu(forItem item: Any)
  {
    switch item {
      case is XTRemoteBranchItem:
        menu = prepBranchMenu(controller.remoteBranchContextMenu, local: false)
      case is XTLocalBranchItem:
        menu = prepBranchMenu(controller.branchContextMenu, local: true)
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
  
  func prepBranchMenu(_ menu: NSMenu, local: Bool) -> NSMenu
  {
    let renameIndex = menu.indexOfItem(
            withTarget: controller,
            andAction: #selector(XTSidebarController.renameBranch(_:)))
    
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
