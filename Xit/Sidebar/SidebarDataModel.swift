import Foundation

/// Contains the items listed in the sidebar
class SidebarDataModel
{
  typealias Repository = FileChangesRepo & // For creating selection objects
                         CommitStorage & // also for selections
                         Branching & RemoteManagement &
                         SubmoduleManagement & Stashing

  private(set) weak var repository: Repository?
  private(set) weak var outline: NSOutlineView?
  var roots: [SideBarGroupItem] = []

  var stagingItem: SidebarItem { return roots[0].children[0] }
  
  func makeRoots() -> [SideBarGroupItem]
  {
    let stagingItem = StagingSidebarItem(titleString: .staging)
    let rootNames: [UIString] =
          [.workspace, .branches, .remotes, .tags, .stashes, .submodules]
    let roots = rootNames.map { SideBarGroupItem(titleString: $0) }
    
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
  
  func parent(for branchPath: [String],
              under item: SidebarItem) -> SidebarItem
  {
    if branchPath.count == 1 {
      return item
    }
    
    let folderName = branchPath[0]
    
    if let child = item.children.first(where: { $0.expandable &&
                                                $0.title == folderName }) {
      return parent(for: Array(branchPath.dropFirst(1)), under: child)
    }
    
    let newItem = BranchFolderSidebarItem(title: folderName)
    
    item.children.append(newItem)
    return newItem
  }
  
  func parent(for branch: String, groupItem: SidebarItem) -> SidebarItem
  {
    return parent(for: branch.components(separatedBy: "/"), under: groupItem)
  }

  func makeStashItems() -> [SidebarItem]
  {
    return repository?.stashes.map {
      StashSidebarItem(title: $0.message ?? "stash",
                  selection: StashSelection(repository: repository!, stash: $0))
    } ?? []
  }
  
  func reload()
  {
    let newRoots = loadRoots()

    Thread.syncOnMainThread {
      roots = newRoots
    }
  }
  
  func loadRoots() -> [SideBarGroupItem]
  {
    guard let repo = repository
    else { return [] }
    
    let newRoots = makeRoots()
    let branchesGroup = newRoots[XTGroupIndex.branches.rawValue]
    let localBranches = repo.localBranches.sorted { $0.name <~ $1.name }
    
    for branch in localBranches {
      guard let sha = branch.oid?.sha,
            let commit = repo.commit(forSHA: sha)
      else { continue }
      
      let name = branch.name.droppingPrefix("refs/heads/")
      let selection = CommitSelection(repository: repo, commit: commit)
      let branchItem = LocalBranchSidebarItem(title: name, selection: selection)
      let parent = self.parent(for: name, groupItem: branchesGroup)
      
      parent.children.append(branchItem)
    }
    
    let remoteItems = repo.remoteNames().map {
          RemoteSidebarItem(title: $0, repository: repo) }
    let remoteBranches = repo.remoteBranches.sorted { $0.name <~ $1.name }

    for branch in remoteBranches {
      guard let remote = remoteItems.first(where: { $0.title ==
                                                    branch.remoteName }),
            let remoteName = branch.remoteName,
            let oid = branch.oid,
            let commit = repo.commit(forOID: oid)
      else { continue }
      let name = branch.name.droppingPrefix("refs/remotes/\(remote.title)/")
      let selection = CommitSelection(repository: repo, commit: commit)
      let remoteParent = parent(for: name, groupItem: remote)
      
      remoteParent.children.append(RemoteBranchSidebarItem(title: name,
                                                           remote: remoteName,
                                                           selection: selection))
    }
    
    Signpost.interval(.loadTags) {
      if let tags = try? repo.tags().sorted(by: { $0.name <~ $1.name }) {
        let tagsGroup = newRoots[XTGroupIndex.tags.rawValue]
        
        for tag in tags {
          let tagItem = TagSidebarItem(tag: tag)
          let tagParent = parent(for: tag.name, groupItem: tagsGroup)
          
          tagParent.children.append(tagItem)
        }
      }
    }
    
    let stashItems = makeStashItems()
    let submoduleItems = repo.submodules().map {
          SubmoduleSidebarItem(submodule: $0) }
    
    newRoots[XTGroupIndex.remotes.rawValue].children = remoteItems
    newRoots[XTGroupIndex.stashes.rawValue].children = stashItems
    newRoots[XTGroupIndex.submodules.rawValue].children = submoduleItems
    
    repo.rebuildRefsIndex()
    //viewController.reloadFinished()
    return newRoots
  }
}
