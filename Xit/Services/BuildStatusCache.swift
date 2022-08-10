import Foundation
@preconcurrency import Siesta

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
      let localBranches = branchLister.localBranches

      await Signpost.interval(.refreshBuildStatus) {
        for local in localBranches {
          guard let remoteName = local.trackingBranch?.remoteName
          else { continue }

          do {
            try await refresh(remoteName: remoteName,
                              branchName: local.name)
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
  func refresh(remoteName: String, branchName: String) async throws
  {
    guard let (api, buildTypes) = matchBuildStatusService(remoteName)
    else {
      throw RefreshError.noBuildTypes
    }
  
    try await withThrowingTaskGroup(of: Void.self) {
      (taskGroup) in
      for buildType in buildTypes {
        guard let branchName = api.displayName(forBranch: branchName,
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

          await MainActor.run {
            var buildTypeStatuses = self.statuses[buildType] ?? BranchStatuses()

            buildTypeStatuses[branchName] = build
            self.statuses[buildType] = buildTypeStatuses
          }
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
