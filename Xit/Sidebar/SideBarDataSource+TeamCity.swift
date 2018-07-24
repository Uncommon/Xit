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
      return remoteBranchItem.remote
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
  
  /// Returns true if the remote branch is tracked by a local branch.
  func branchHasLocalTrackingBranch(_ branch: String) -> Bool
  {
    for localBranch in repository.localBranches() {
      if let trackingBranch = localBranch.trackingBranch,
         trackingBranch.shortName == branch {
        return true
      }
    }
    return false
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
          (branchItem is LocalBranchSidebarItem ||
           branchHasLocalTrackingBranch(item.title))
    else { return nil }
    
    guard let remoteName = remoteName(forBranchItem: item),
          let (api, buildTypes) = matchTeamCity(remoteName)
    else { return nil }
    
    var overallSuccess: Bool?
    
    for buildType in buildTypes {
      if let branchName = api.displayName(forBranch: branchItem.refName,
                                          buildType: buildType),
         let status = buildStatusCache.statuses[buildType],
         let buildSuccess = status[branchName].map({ $0.status == .succeeded }) {
        overallSuccess = (overallSuccess ?? true) && buildSuccess
      }
    }
    
    if let success = overallSuccess {
      return NSImage(named: success ? .statusAvailable : .statusUnavailable)
    }
    else {
      return NSImage(named: .statusNone)
    }
  }
}

// MARK: BuildStatusClient
extension SideBarDataSource: BuildStatusClient
{
  func buildStatusUpdated(branch: String, buildType: String)
  {
    scheduleReload()
  }
}
