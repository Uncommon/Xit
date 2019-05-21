import Foundation

class SidebarDataModel
{
  typealias Repository = FileChangesRepo & // For creating selection objects
                         CommitStorage & // also for selections
                         Branching & RemoteManagement &
                         SubmoduleManagement & Stashing &
                         TaskManagement // For loading off the main thread

  private(set) weak var repository: Repository?
  private(set) weak var outline: NSOutlineView?
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
  
  init(repository: Repository, outlineView: NSOutlineView?)
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
  
  /// Returns the name of the remote for either a remote branch or a local
  /// tracking branch.
  func remoteName(forBranchItem branchItem: SidebarItem) -> String?
  {
    guard let repo = repository
    else { return nil }
    
    if let remoteBranchItem = branchItem as? RemoteBranchSidebarItem {
      return remoteBranchItem.remoteName
    }
    else if let localBranchItem = branchItem as? LocalBranchSidebarItem {
      guard let branch = repo.localBranch(named: localBranchItem.title)
      else {
        NSLog("Can't get branch for branch item: \(branchItem.title)")
        return nil
      }
      
      return branch.trackingBranch?.remoteName
    }
    return nil
  }
}
