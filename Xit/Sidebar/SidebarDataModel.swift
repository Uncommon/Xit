import Foundation

class SidebarDataModel
{
  private(set) weak var repository: XTRepository?
  let outline: NSOutlineView
  var roots: [SideBarGroupItem] = []

  var stagingItem: SidebarItem { return roots[0].children[0] }
  
  func makeRoots() -> [SideBarGroupItem]
  {
    let stagingItem = StagingSidebarItem(titleString: .staging)
    let rootNames: [UIString] =
          [.workspace, .branches, .remotes, .tags, .stashes, .submodules]
    var roots = rootNames.map { SideBarGroupItem(titleString: $0) }
    
    stagingItem.selection = StagingSelection(repository: repository!)
    roots[0].children.append(stagingItem)
    return roots
  }
  
  init(repository: XTRepository, outlineView: NSOutlineView)
  {
    self.repository = repository
    self.outline = outlineView
    
    roots = makeRoots()
  }
  
  func rootItem(_ index: XTGroupIndex) -> SideBarGroupItem
  {
    return roots[index.rawValue]
  }
  
  func item(forBranchName branch: String) -> LocalBranchSidebarItem?
  {
    let branches = roots[XTGroupIndex.branches.rawValue]
    let result = branches.children.first { $0.title == branch }
    
    return result as? LocalBranchSidebarItem
  }
  
  func item(named name: String, inGroup group: XTGroupIndex) -> SidebarItem?
  {
    let group = roots[group.rawValue]
    
    return group.child(matching: name)
  }
}
