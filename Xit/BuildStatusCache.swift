import Foundation

protocol BuildStatusClient: class
{
  func buildStatusUpdated(branch: String, buildType: String)
}

class BuildStatusCache: TeamCityAccessor
{
  // This typealias resolves ambiguity for the compiler
  typealias BranchStatuses = [String: TeamCityAPI.Build] // Branch to build

  weak var repository: XTRepository!
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
  
  init(repository: XTRepository)
  {
    self.repository = repository
  }
  
  func add(client: BuildStatusClient)
  {
    if !clients.contains(where: { $0.client === client }) {
      clients.append(WeakClientRef(client: client))
    }
  }
  
  func remove(client: BuildStatusClient)
  {
    clients.index(where: { $0.client === client })
           .map { _ = clients.remove(at: $0) }
  }
  
  func refresh()
  {
    guard let repository = self.repository
    else { return }
    let localBranches = repository.localBranches()
    
    statuses.removeAll()
    for local in localBranches {
      guard let tracked = local.trackingBranch,
            let remoteName = tracked.remoteName,
            let (api, buildTypes) = matchTeamCity(remoteName)
      else { continue }
      
      let fullBranchName = local.name
      
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
          self.clients.forEach {
            $0.client?.buildStatusUpdated( branch: branchName,
                                           buildType: buildType)
          }
        }
      }
    }
  }
}
