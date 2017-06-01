import Foundation

protocol BuildStatusClient: class
{
  func buildStatusUpdated(branch: String, buildType: String)
}

class BuildStatusCache: TeamCityAccessor
{
  // This typealias resolves ambiguity for the compiler
  typealias BranchStatuses = [String: TeamCityAPI.Build]

  let repository: XTRepository
  var statuses = [String: BranchStatuses]()
  private var clients = [BuildStatusClient]()
  
  init(repository: XTRepository)
  {
    self.repository = repository
  }
  
  func add(client: BuildStatusClient)
  {
    if !clients.contains(where: { $0 === client }) {
      clients.append(client)
    }
  }
  
  func remove(client: BuildStatusClient)
  {
    clients.index(where: { $0 === client }).map { _ = clients.remove(at: $0) }
  }
  
  func refresh()
  {
    let localBranches = repository.localBranches()
    
    statuses.removeAll()
    for local in localBranches {
      guard let fullBranchName = local.name,
            let tracked = local.trackingBranch,
            let (api, buildTypes) = matchTeamCity(tracked.remoteName)
      else { continue }
      
      for buildType in buildTypes {
        let vcsRoots = api.vcsRootsForBuildType(buildType)
        guard !vcsRoots.isEmpty
        else { continue }
        
        let displayNames = vcsRoots.flatMap
              { api.vcsBranchSpecs[$0]?.match(branch: fullBranchName) }
        guard let branchName = displayNames.reduce(nil, {
          (shortest, name) -> String? in
          return (shortest.map { $0.characters.count < name.characters.count }
                  ?? false)
                 ? shortest : name
        })
        else { continue }
        
        let statusResource = api.buildStatus(branchName, buildType: buildType)
        
        statusResource.useData(owner: self) {
          (data) in
          guard let xml = data.content as? XMLDocument,
                let firstBuildElement =
                xml.rootElement()?.children?.first as? XMLElement,
                let build = TeamCityAPI.Build(element: firstBuildElement)
          else { return }
          
          NSLog("\(buildType)/\(branchName): \(build.status?.rawValue ?? "?")")
          var buildTypeStatuses = self.statuses[buildType] ??
                                  BranchStatuses()
          
          buildTypeStatuses[branchName] = build
          self.statuses[buildType] = buildTypeStatuses
          self.clients.forEach { $0.buildStatusUpdated(branch: branchName,
                                                       buildType: buildType) }
        }
      }
    }
  }
}
