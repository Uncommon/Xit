import Foundation

extension SideBarDataSource: TeamCityAccessor
{
  var remoteMgr: RemoteManagement! { return repository }
  
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
  
  /// Returns the local branch that tracks the given remote branch ref.
  func localTrackingBranch(forBranchRef branch: String) -> LocalBranch?
  {
    for localBranch in repository.localBranches() {
      if let trackingBranch = localBranch.trackingBranch,
         trackingBranch.name == branch {
        return localBranch
      }
    }
    return nil
  }
  
  /// Returns true if the local branch has a remote tracking branch.
  func localBranchHasTrackingBranch(_ branch: String) -> Bool
  {
    return repository.localBranch(named: branch)?.trackingBranch != nil
  }
  
  func trackingBranchStatus(for branch: String) -> TrackingBranchStatus
  {
    if let localBranch = repository.localBranch(named: branch),
       let trackingBranchName = localBranch.trackingBranchName {
      return repository.remoteBranch(named: trackingBranchName) == nil
          ? .missing(trackingBranchName)
          : .set(trackingBranchName)
    }
    else {
      return .none
    }
  }
  
  func statusImage(for item: SidebarItem) -> NSImage?
  {
    guard let branchItem = item as? BranchSidebarItem,
          let refName = (branchItem as? RefSidebarItem)?.refName,
          let localBranch = branchItem.branchObject() as? LocalBranch ??
                            localTrackingBranch(forBranchRef: refName)
    else { return nil }

    guard let remoteName = remoteName(forBranchItem: item),
          let (api, buildTypes) = matchTeamCity(remoteName)
    else { return nil }
    
    var overallSuccess: Bool?
    
    for buildType in buildTypes {
      if let branchName = api.displayName(forBranch: localBranch.name,
                                          buildType: buildType),
         let status = buildStatusCache.statuses[buildType],
         let buildSuccess = status[branchName].map({ $0.status == .succeeded }) {
        overallSuccess = (overallSuccess ?? true) && buildSuccess
      }
    }
    
    if let success = overallSuccess {
      return NSImage(named: success ? NSImage.statusAvailableName
                                    : NSImage.statusUnavailableName)
    }
    else {
      return NSImage(named: NSImage.statusNoneName)
    }
  }
}

// MARK: BuildStatusClient
extension SideBarDataSource: BuildStatusClient
{
  func buildStatusUpdated(branch: String, buildType: String)
  {
    updateBranches(model.rootItem(.branches).children)
    for remoteItem in model.rootItem(.remotes).children {
      updateBranches(remoteItem.children)
    }
  }
  
  private func updateBranches(_ branchItems: [SidebarItem])
  {
    for item in branchItems {
      switch item {
        case is BranchSidebarItem:
          updateStatusImage(item: item, cell: nil)
        case is BranchFolderSidebarItem:
          updateBranches(item.children)
        default:
          break
      }
    }
  }
}
