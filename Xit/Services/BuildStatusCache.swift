import Foundation
import XitGit

protocol BuildStatusDisplayService
{
  func cachedVCSRoots(for buildType: String) -> [String]
  func cachedBranchSpec(for vcsRootID: String) -> BranchSpec?
  func cachedBuildTypesSnapshot() -> [BuildType]
}

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
  typealias BranchStatuses = [String: TeamCity.Build] // Branch to build
  
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
      serviceLogger.debug("Build status cache added client \(String(describing: type(of: client)), privacy: .public); total clients: \(self.clients.count)")
    }
  }
  
  func remove(client: any BuildStatusClient)
  {
    clients.removeAll { $0.client === client }
    serviceLogger.debug("Build status cache removed client \(String(describing: type(of: client)), privacy: .public); total clients: \(self.clients.count)")
  }
  
  func refresh()
  {
    guard let branchLister = branchLister
    else {
      serviceLogger.debug("Build status cache refresh skipped because branch lister is nil")
      return
    }
    
    statuses.removeAll()
    Task {
      let localBranches = getLocalBranches(branchLister)
      serviceLogger.debug("Build status cache refresh starting for \(localBranches.count) local branches")
      
      await Signpost.interval(.refreshBuildStatus) {
        for local in localBranches {
          guard let remoteName = local.trackingBranch?.remoteName
          else {
            serviceLogger.debug("Skipping local branch \(local.referenceName.fullPath, privacy: .public) without tracking remote")
            continue
          }
          
          do {
            serviceLogger.debug("Refreshing build status for remote \(remoteName, privacy: .public) branch \(local.referenceName.fullPath, privacy: .public)")
            try await refresh(remoteName: remoteName,
                              branch: local.referenceName)
          }
          catch {
            serviceLogger.debug("Build status refresh failed for remote \(remoteName, privacy: .public) branch \(local.referenceName.fullPath, privacy: .public): \(String(describing: error), privacy: .public)")
          }
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
      serviceLogger.debug("No TeamCity build types matched remote \(remoteName, privacy: .public) for branch \(branch.fullPath, privacy: .public)")
      throw RefreshError.noBuildTypes
    }
    serviceLogger.debug("Refreshing TeamCity build statuses using \(api.account.location.absoluteString, privacy: .public) for remote \(remoteName, privacy: .public) branch \(branch.fullPath, privacy: .public) with build types \(buildTypes, privacy: .public)")
    
    try await withThrowingTaskGroup(of: Void.self) {
      (taskGroup) in
      for buildType in buildTypes {
        let displayName = await api.displayName(for: branch,
                                                buildType: buildType)
        guard let branchName = displayName
        else {
          serviceLogger.debug("No TeamCity display name for branch \(branch.fullPath, privacy: .public) build type \(buildType, privacy: .public)")
          continue
        }
        serviceLogger.debug("Loading TeamCity builds for build type \(buildType, privacy: .public) branch display name \(branchName, privacy: .public)")
        
        taskGroup.addTask {
          let builds = try await api.loadBuilds(buildTypeID: buildType,
                                                branch: branchName)
          guard let build = builds.first
          else {
            serviceLogger.debug("TeamCity returned no builds for build type \(buildType, privacy: .public) branch \(branchName, privacy: .public)")
            return
          }
          
          await MainActor.run {
            var buildTypeStatuses = self.statuses[buildType] ?? BranchStatuses()
            
            buildTypeStatuses[branchName] = build
            self.statuses[buildType] = buildTypeStatuses
            serviceLogger.debug("Cached TeamCity build status for build type \(buildType, privacy: .public) branch \(branchName, privacy: .public); cached branches now: \(buildTypeStatuses.keys.sorted(), privacy: .public)")
            
            for ref in self.clients {
              serviceLogger.debug("Notifying build status client \(String(describing: ref.client.map { type(of: $0) }), privacy: .public) for build type \(buildType, privacy: .public) branch \(branchName, privacy: .public)")
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
    -> (TeamCityService, [String])?
  {
    guard let remoteMgr = self.remoteMgr,
          let remote = remoteMgr.remote(named: remoteName),
          let remoteURL = remote.urlString
    else {
      serviceLogger.debug("Failed to resolve remote URL for TeamCity matching on remote \(remoteName, privacy: .public)")
      return nil
    }
    let result = await servicesMgr.teamCityBuildStatus(for: remoteURL)
    if let (_, buildTypes) = result {
      serviceLogger.debug("Matched TeamCity build types \(buildTypes, privacy: .public) for remote \(remoteName, privacy: .public) URL \(remoteURL, privacy: .public)")
    }
    else {
      serviceLogger.debug("No TeamCity build status service matched remote \(remoteName, privacy: .public) URL \(remoteURL, privacy: .public)")
    }
    return result
  }
  
  func matchBuildStatusService(_ remoteName: String) -> (any BuildStatusDisplayService)?
  {
    guard let remoteMgr = self.remoteMgr,
          let remote = remoteMgr.remote(named: remoteName),
          let host = remote.url?.host
    else {
      serviceLogger.debug("Failed to resolve remote host for build status display matching on remote \(remoteName, privacy: .public)")
      return nil
    }
    let service = servicesMgr.teamCityService(host: host)
    serviceLogger.debug("Display service match for remote \(remoteName, privacy: .public) host \(host, privacy: .public): \(service == nil ? "none" : "TeamCity")")
    return service
  }
}
