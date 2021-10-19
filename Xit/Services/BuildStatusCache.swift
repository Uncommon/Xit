import Foundation

protocol BuildStatusClient: AnyObject
{
  func buildStatusUpdated(branch: String, buildType: String)
}

final class BuildStatusCache: TeamCityAccessor
{
  // This typealias resolves ambiguity for the compiler
  typealias BranchStatuses = [String: TeamCityAPI.Build] // Branch to build

  weak var remoteMgr: RemoteManagement!
  weak var branchLister: Branching?
  var statuses = [String: BranchStatuses]() // Build type to branch builds
  private var clients = [WeakClientRef]()
  
  class WeakClientRef
  {
    weak var client: BuildStatusClient?
    
    init(client: BuildStatusClient)
    {
      self.client = client
    }
  }
  
  init(branchLister: Branching, remoteMgr: RemoteManagement)
  {
    self.remoteMgr = remoteMgr
    self.branchLister = branchLister
  }
  
  func add(client: BuildStatusClient)
  {
    if !clients.contains(where: { $0.client === client }) {
      clients.append(WeakClientRef(client: client))
    }
  }
  
  func remove(client: BuildStatusClient)
  {
    clients.removeAll { $0.client === client }
  }
  
  func refresh()
  {
    guard let localBranches = branchLister?.localBranches
    else { return }
    
    statuses.removeAll()
    Signpost.interval(.refreshBuildStatus) {
      for local in localBranches {
        refresh(branch: local)
      }
    }
  }
  
  func refresh(branch: LocalBranch, onFailure: (() -> Void)? = nil)
  {
    guard let tracked = branch.trackingBranch,
          let remoteName = tracked.remoteName,
          let (api, buildTypes) = matchTeamCity(remoteName)
    else {
      onFailure?()
      return
    }
  
    let fullBranchName = branch.name
  
    for buildType in buildTypes {
      guard let branchName = api.displayName(forBranch: fullBranchName,
                                             buildType: buildType)
      else { continue }
      
      let statusResource = api.buildStatus(branchName, buildType: buildType)
      
      statusResource.invalidate()
      statusResource.useData(owner: self) {
        (data) in
        guard let xml = data.content as? XMLDocument,
              let firstBuildElement = xml.rootElement()?.children?.first
                                      as? XMLElement,
              let build = TeamCityAPI.Build(element: firstBuildElement)
        else {
          onFailure?()
          return
        }
        
        var buildTypeStatuses = self.statuses[buildType] ?? BranchStatuses()
        
        buildTypeStatuses[branchName] = build
        self.statuses[buildType] = buildTypeStatuses
        for ref in self.clients {
          ref.client?.buildStatusUpdated(branch: branchName,
                                         buildType: buildType)
        }
      }
    }
  }
}
