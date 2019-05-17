import Foundation

extension SideBarDataSource: TeamCityAccessor
{
  var remoteMgr: RemoteManagement! { return repository }
  
  func statusImage(for item: SidebarItem) -> NSImage?
  {
    guard let branchItem = item as? BranchSidebarItem,
          let refName = (branchItem as? RefSidebarItem)?.refName,
          let localBranch = branchItem.branchObject() as? LocalBranch ??
                            repository.localTrackingBranch(forBranchRef: refName)
    else { return nil }

    guard let remoteName = model.remoteName(forBranchItem: item),
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
