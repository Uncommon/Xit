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
  
  func item(forBranchName branch: String) -> LocalBranchSidebarItem?
  {
    return nil
    //let branches = roots[SidebarGroupIndex.branches.rawValue]
    //let result = branches.children.first { $0.title == branch }
    //
    //return result as? LocalBranchSidebarItem
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
        guard let refName = LocalBranchRefName.named(localBranchItem.title),
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
    return []
  }
}
