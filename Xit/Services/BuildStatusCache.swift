import Foundation

protocol BuildStatusClient: AnyObject
{
  func buildStatusUpdated(branch: String, buildType: String)
}

final class BuildStatusCache: TeamCityAccessor
{
  // This typealias resolves ambiguity for the compiler
  typealias BranchStatuses = [String: TeamCityAPI.Build] // Branch to build

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
    guard let localBranches = branchLister?.localBranches
    else { return }
    
    statuses.removeAll()
    Task {
      await Signpost.interval(.refreshBuildStatus) {
        for local in localBranches {
          do {
            try await refresh(branch: local)
          }
          catch {}
        }
      }
    }
  }

  enum RefreshError: Error
  {
    case noBuildTypes
    case parseFailure
  }

  @MainActor
  func refresh(branch: any LocalBranch) async throws
  {
    guard let tracked = branch.trackingBranch,
          let remoteName = tracked.remoteName,
          let (api, buildTypes) = matchTeamCity(remoteName)
    else {
      throw RefreshError.noBuildTypes
    }
  
    let fullBranchName = branch.name

    try await withThrowingTaskGroup(of: Void.self) {
      (taskGroup) in
      for buildType in buildTypes {
        guard let branchName = api.displayName(forBranch: fullBranchName,
                                               buildType: buildType)
        else { continue }
        let statusResource = api.buildStatus(branchName, buildType: buildType)

        statusResource.invalidate()
        taskGroup.addTask {
          let data = try await statusResource.data
          guard let xml = data.content as? XMLDocument
          else {
            throw RefreshError.parseFailure
          }
          guard let firstBuildElement = xml.rootElement()?.children?.first
                                        as? XMLElement,
                let build = TeamCityAPI.Build(element: firstBuildElement)
          else {
            // failed to find matching branch; ignore and continue
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
      try await taskGroup.waitForAll()
    }
  }
}
