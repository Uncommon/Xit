import Foundation
import Cocoa

/// Contains the items listed in the sidebar
///
/// `@unchecked Sendable` because it is guarded by locks and queues.
final class SidebarDataModel: @unchecked Sendable
{
  typealias Repository = FileChangesRepo & // For creating selection objects
                         CommitStorage & // also for selections
                         Branching & RemoteManagement &
                         SubmoduleManagement & Stashing & Tagging

  private(set) weak var repository: (any Repository)?
  var roots: [SideBarGroupItem] = []

  var stagingItem: SidebarItem { roots[0].children[0] }
  
  func makeRoots() -> [SideBarGroupItem]
  {
    let stagingItem = StagingSidebarItem(titleString: .staging)
    let rootNames: [UIString] =
          [.workspace, .branches, .remotes, .tags, .stashes, .submodules]
    let roots = rootNames.map { SideBarGroupItem(titleString: $0) }
    
    stagingItem.selection = StagingSelection(repository: repository!,
                                             amending: false)
    roots[0].children.append(stagingItem)
    return roots
  }
  
  init(repository: any Repository)
  {
    self.repository = repository

    roots = makeRoots()
  }
  
  func rootItem(_ index: SidebarGroupIndex) -> SideBarGroupItem
  {
    return roots[index.rawValue]
  }
  
  func item(forBranchName branch: String) -> LocalBranchSidebarItem?
  {
    let branches = roots[SidebarGroupIndex.branches.rawValue]
    let result = branches.children.first { $0.title == branch }
    
    return result as? LocalBranchSidebarItem
  }
  
  func item(named name: String, inGroup group: SidebarGroupIndex) -> SidebarItem?
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
    
    switch branchItem {
      case let remoteBranchItem as RemoteBranchSidebarItem:
        return remoteBranchItem.remoteName
      case let localBranchItem as LocalBranchSidebarItem:
        guard let refName = LocalBranchRefName(localBranchItem.title),
              let branch = repo.localBranch(named: refName)
        else {
          repoLogger.debug("Can't get branch for branch item: \(branchItem.title)")
          return nil
        }
        
        return branch.trackingBranch?.remoteName
      default:
        return nil
    }
  }
  
  func parent(for branchPath: [String],
              under item: SidebarItem) -> SidebarItem
  {
    if branchPath.count == 1 {
      return item
    }
    
    let folderName = branchPath[0]
    
    if let child = item.children.first(where: { $0.isExpandable &&
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
    repository.map { makeStashItems($0) } ?? []
  }

  func makeStashItems<R>(_ repository: R) -> [SidebarItem]
    where R: Stashing & FileChangesRepo
  {
    repository.stashes.map {
      StashSidebarItem(title: $0.message ?? "stash",
                       selection: StashSelection(repository: repository,
                                                 stash: $0))
    }
  }
  
  nonisolated func reload()
  {
    let newRoots = loadRoots()

    Thread.syncOnMain {
      roots = newRoots
    }
  }
  
  func loadRoots() -> [SideBarGroupItem]
  {
    guard let repo = repository
    else { return [] }

    return loadRoots(repo)
  }

  func loadRoots(_ repo: some Repository) -> [SideBarGroupItem]
  {
    let newRoots = makeRoots()
    let branchesGroup = newRoots[SidebarGroupIndex.branches.rawValue]
    let localBranches = repo.localBranches.sorted
    { $0.referenceName <~ $1.referenceName }

    for branch in localBranches {
      guard let oid = branch.oid,
            let commit = repo.commit(forOID: oid)
      else { continue }
      
      let name = branch.referenceName.name
      let selection = CommitSelection(repository: repo, commit: commit)
      let branchItem = LocalBranchSidebarItem(title: name, selection: selection)
      let parent = self.parent(for: name, groupItem: branchesGroup)
      
      parent.children.append(branchItem)
    }
    
    let remoteItems = repo.remoteNames().map {
          RemoteSidebarItem(title: $0, repository: repo) }
    let remoteBranches = repo.remoteBranches.sorted
    { $0.referenceName <~ $1.referenceName }

    for branch in remoteBranches {
      guard let remote = remoteItems.first(where: { $0.title ==
                                                    branch.remoteName }),
            let remoteName = branch.remoteName,
            let oid = branch.oid,
            let commit = repo.commit(forOID: oid)
      else { continue }
      let name = branch.referenceName.localName
      let selection = CommitSelection(repository: repo, commit: commit)
      let remoteParent = parent(for: name, groupItem: remote)
      
      remoteParent.children.append(RemoteBranchSidebarItem(title: name,
                                                           remote: remoteName,
                                                           selection: selection))
    }
    
    Signpost.interval(.loadTags) {
      guard let tags = try? repo.tags() as [any Tag]
      else { return }
      let sortedTags = tags.sorted(by: { $0.name <~ $1.name })
      let tagsGroup = newRoots[SidebarGroupIndex.tags.rawValue]
      
      for tag in sortedTags {
        let tagItem = TagSidebarItem(tag: tag)
        let tagParent = parent(for: tag.name, groupItem: tagsGroup)
        
        tagParent.children.append(tagItem)
      }
    }
    
    let stashItems = makeStashItems()
    let submoduleItems = repo.submodules().map {
          SubmoduleSidebarItem(submodule: $0) }
    
    newRoots[SidebarGroupIndex.remotes.rawValue].children = remoteItems
    newRoots[SidebarGroupIndex.stashes.rawValue].children = stashItems
    newRoots[SidebarGroupIndex.submodules.rawValue].children = submoduleItems
    
    repo.rebuildRefsIndex()
    return newRoots
  }
}
