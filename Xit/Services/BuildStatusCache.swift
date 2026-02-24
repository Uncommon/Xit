import Foundation

protocol BuildStatusAccessor: AnyObject
{
  var servicesMgr: Services { get }
  var remoteMgr: (any RemoteManagement)! { get }
}

protocol BuildStatusClient: AnyObject
{
  func buildStatusUpdated(branch: String, buildType: String)
}

final class BuildStatusCache: BuildStatusAccessor
{
  // This typealias resolves ambiguity for the compiler
  typealias BranchStatuses = [String: TeamCityAPI.Build] // Branch to build
  
  var servicesMgr: Services { Services.xit }
  weak var remoteMgr: (any RemoteManagement)!
  weak var branchLister: (any Branching)?
  var statuses = [String: BranchStatuses]() // Build type to branch builds
  private var clients = [WeakClientRef]()
  
  class WeakClientRef
  {
    weak var client: (any BuildStatusClient)?
    
    init(client: any BuildStatusClient)
    {
      self.client = client
    }
  }
  
  init(branchLister: any Branching, remoteMgr: any RemoteManagement)
  {
    self.remoteMgr = remoteMgr
    self.branchLister = branchLister
  }
  
  func add(client: any BuildStatusClient)
  {
    if !clients.contains(where: { $0.client === client }) {
      clients.append(WeakClientRef(client: client))
    }
  }
  
  func remove(client: any BuildStatusClient)
  {
    clients.removeAll { $0.client === client }
  }
  
  func refresh()
  {
    guard let branchLister = branchLister
    else { return }
    
    statuses.removeAll()
    Task {
      let localBranches = getLocalBranches(branchLister)
      
      await Signpost.interval(.refreshBuildStatus) {
        for local in localBranches {
          guard let remoteName = local.trackingBranch?.remoteName
          else { continue }
          
          do {
            try await refresh(remoteName: remoteName,
                              branch: local.referenceName)
          }
          catch {}
        }
      }
    }
  }
  
  func getLocalBranches(_ repository: some Branching) -> [any LocalBranch]
  {
    repository.localBranches.map { $0 }
  }
  
  enum RefreshError: Error
  {
    case noBuildTypes
    case parseFailure
  }
  
  @MainActor
  func refresh(remoteName: String, branch: LocalBranchRefName) async throws
  {
    guard let (api, buildTypes) = await matchBuildStatusServiceAndTypes(remoteName)
    else {
      throw RefreshError.noBuildTypes
    }
    
    try await withThrowingTaskGroup(of: Void.self) {
      (taskGroup) in
      for buildType in buildTypes {
        let displayName = await api.displayName(for: branch,
                                                buildType: buildType)
        guard let branchName = displayName
        else { continue }
        
        taskGroup.addTask {
          let builds = try await api.loadBuilds(buildTypeID: buildType,
                                                branch: branchName)
          guard let build = builds.first
          else { return }
          
          await MainActor.run {
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
      try await taskGroup.waitForAll()
    }
  }
}

extension BuildStatusAccessor
{
  /// Returns the first TeamCity HTTP service that builds from the given
  /// repository, and a list of its build types.
  func matchBuildStatusServiceAndTypes(_ remoteName: String) async
    -> (TeamCityHTTPService, [String])?
  {
    guard let remoteMgr = self.remoteMgr,
          let remote = remoteMgr.remote(named: remoteName),
          let remoteURL = remote.urlString
    else { return nil }
    
    return await servicesMgr.teamCityHTTPBuildStatus(for: remoteURL)
  }
  
  func matchBuildStatusService(_ remoteName: String) -> TeamCityHTTPService?
  {
    guard let remoteMgr = self.remoteMgr,
          let remote = remoteMgr.remote(named: remoteName),
          let host = remote.url?.host
    else { return nil }
    
    return servicesMgr.teamCityHTTPService(host: host)
  }
}
