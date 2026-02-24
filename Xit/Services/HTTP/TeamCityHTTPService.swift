import Foundation

/// URLSession-based TeamCity service (parallel to Siesta-backed TeamCityAPI).
/// Provides async endpoints; not yet wired into UI or Services.
final class TeamCityHTTPService: BaseHTTPService
{
  nonisolated static let rootPath = TeamCityAPI.rootPath // reuse existing constant
  
  private var vcsRootMap: [String: URL] = [:]
  private var vcsBranchSpecs: [String: BranchSpec] = [:]
  private var buildTypeURLs: [String: [URL]] = [:]
  private var buildTypesCache: [String: [String]] = [:]
  private var vcsRootsCache: [String: [String]] = [:]
  private var cachedBuildTypes: [BuildType] = []
  
  /// Tracks build type loading status (mirrors legacy API)
  @MainActor @Published var buildTypesStatus: Services.Status = .notStarted
  
  /// Fetch build types list (raw XML data for now).
  func fetchBuildTypes() async throws -> Data
  {
    let endpoint = Endpoint(baseURL: account.location,
                            path: Self.rootPath + "/buildTypes",
                            method: .get)
    return try await networkService.request(endpoint)
  }
  
  /// Fetch builds for a specific build type and optional branch.
  func fetchBuilds(buildTypeID: String, branch: String? = nil) async throws -> Data
  {
    var locator = "affectedProject:(id:\(buildTypeID))"
    if let branch {
      locator += ",branch:\(branch)"
    }
    let path = Self.rootPath + "/builds/?locator=" + locator
    
    let endpoint = Endpoint(baseURL: account.location,
                            path: path,
                            method: .get)
    return try await networkService.request(endpoint)
  }
  
  /// Fetch build status by href (raw XML data).
  func fetchBuild(href: String) async throws -> Data
  {
    let path = href.hasPrefix("/") ? href : "/" + href
    let endpoint = Endpoint(baseURL: account.location,
                            path: path,
                            method: .get)
    return try await networkService.request(endpoint)
  }
  
  enum ParseError: Error
  {
    case invalidXML
    case missingRoot
    case missingBuildTypes
    case missingBuilds
  }
  
  /// Fetch build types and parse into models.
  func loadBuildTypes() async throws -> [BuildType]
  {
    let data = try await fetchBuildTypes()
    
    return try parseBuildTypes(from: data)
  }
  
  /// Fetch builds and parse into models.
  func loadBuilds(buildTypeID: String, branch: String? = nil) async throws -> [TeamCityAPI.Build]
  {
    let data = try await fetchBuilds(buildTypeID: buildTypeID, branch: branch)
    
    return try parseBuilds(from: data)
  }
  
  /// Fetch list of VCS roots (summary XML).
  func fetchVCSRoots() async throws -> Data
  {
    let endpoint = Endpoint(baseURL: account.location,
                            path: Self.rootPath + "/vcs-roots",
                            method: .get)
    
    return try await networkService.request(endpoint)
  }
  
  /// Fetch a specific VCS root definition by ID.
  func fetchVCSRoot(id: String) async throws -> Data
  {
    let endpoint = Endpoint(baseURL: account.location,
                            path: Self.rootPath + "/vcs-roots/id:\(id)",
                            method: .get)
    
    return try await networkService.request(endpoint)
  }
  
  /// Load VCS roots and populate URL + branch spec caches.
  func loadVCSRoots() async throws
  {
    let listData = try await fetchVCSRoots()
    let xml = try XMLDocument(data: listData)
    guard let root = xml.rootElement()
    else { throw ParseError.missingRoot }
    
    let rootIDs = root.childrenAttributes("id")
    
    try await withThrowingTaskGroup(of: Void.self) {
      group in
      for rootID in rootIDs {
        group.addTask {
          let data = try await self.fetchVCSRoot(id: rootID)
          let xml = try XMLDocument(data: data)
          
          self.parseVCSRoot(xml: xml, vcsRootID: rootID)
        }
      }
      try await group.waitForAll()
    }
  }
  
  /// Returns a cached build type with a matching ID
  func buildType(id: String) async -> BuildType?
  { cachedBuildTypes.first { $0.id == id } }
  
  /// Returns all the build types that use the given remote.
  func buildTypesForRemote(_ remoteURLString: String) async -> [String]
  {
    if let cached = buildTypesCache[remoteURLString] {
      return cached
    }
    guard let remoteURL = URL(string: remoteURLString)
    else { return [] }
    func matchHostPath(_ url: URL) -> Bool { remoteURL.host == url.host && remoteURL.path == url.path }
    let result = buildTypeURLs.keys.filter { buildTypeURLs[$0]?.contains(where: matchHostPath) ?? false }
    
    buildTypesCache[remoteURLString] = result
    return result
  }
  
  /// Returns the VCS root IDs that use the given build type.
  func vcsRootsForBuildType(_ buildType: String) async -> [String]
  {
    if let cached = vcsRootsCache[buildType] { return cached }
    guard let urls = buildTypeURLs[buildType]
    else { return [] }
    let result = vcsRootMap.compactMap { (vcsRoot, rootURL) in urls.contains(rootURL) ? vcsRoot : nil }
    
    vcsRootsCache[buildType] = result
    return result
  }
  
  /// Use the branch specs to determine display name for the given build type
  func displayName(for branch: LocalBranchRefName, buildType: String) async -> String?
  {
    let rootIDs = await vcsRootsForBuildType(buildType)
    let displayNames = rootIDs.compactMap { vcsBranchSpecs[$0]?.match(branch: branch.fullPath) }
    
    return displayNames.reduce(nil) { shortest, name in (shortest?.count ?? Int.max) < name.count ? shortest : name }
  }
  
  private func parseBuildTypes(from data: Data) throws -> [BuildType]
  {
    let xml = try XMLDocument(data: data)
    guard let root = xml.rootElement()
    else { throw ParseError.missingRoot }
    
    let buildTypeElements = root.elements(forName: "buildType")
    guard !buildTypeElements.isEmpty
    else { throw ParseError.missingBuildTypes }
    
    return buildTypeElements.compactMap {
      element in
      guard let id = element.attribute(forName: "id")?.stringValue,
            let name = element.attribute(forName: "name")?.stringValue
      else { return nil }
      let projectName = element.attribute(forName: "projectName")?.stringValue ?? ""
      return BuildType(id: id, name: name, projectName: projectName)
    }
  }
  
  private func parseBuilds(from data: Data) throws -> [TeamCityAPI.Build]
  {
    let xml = try XMLDocument(data: data)
    guard let root = xml.rootElement()
    else { throw ParseError.missingRoot }
    
    let buildElements = root.elements(forName: "build")
    guard !buildElements.isEmpty
    else { throw ParseError.missingBuilds }
    
    return buildElements.compactMap { TeamCityAPI.Build(element: $0) }
  }
  
  private func parseVCSRoot(xml: XMLDocument, vcsRootID: String)
  {
    guard let properties = xml.rootElement()?.elements(forName: "properties").first,
          let propertiesChildren = properties.children
    else { return }
    
    var url: URL?
    var branchSpec: BranchSpec?
    
    for property in propertiesChildren {
      guard let element = property as? XMLElement,
            let name = element.attribute(forName: "name")?.stringValue,
            let value = element.attribute(forName: "value")?.stringValue
      else { continue }
      
      switch name {
        case "url":
          url = URL(string: value)
        case "teamcity:branchSpec":
          let specLines = value.components(separatedBy: .whitespacesAndNewlines)
          branchSpec = BranchSpec(ruleStrings: specLines)
        default:
          break
      }
    }
    
    if let url { vcsRootMap[vcsRootID] = url }
    if let branchSpec { vcsBranchSpecs[vcsRootID] = branchSpec }
  }
  
  /// Fetch a specific build type definition by ID (includes VCS entries).
  func fetchBuildType(id: String) async throws -> Data
  {
    let endpoint = Endpoint(baseURL: account.location,
                            path: Self.rootPath + "/buildTypes/id:\(id)",
                            method: .get)
    
    return try await networkService.request(endpoint)
  }
  
  /// Full refresh of TeamCity metadata (VCS roots + build types + mappings).
  func refreshMetadata() async
  {
    await MainActor.run { buildTypesStatus = .inProgress }
    
    do {
      try await loadVCSRoots()
      try await refreshBuildTypes()
      await MainActor.run { buildTypesStatus = .done }
    }
    catch {
      await MainActor.run { buildTypesStatus = .failed(error) }
    }
  }
  
  /// Loads build types and fetches details to populate VCS mappings.
  private func refreshBuildTypes() async throws
  {
    let data = try await fetchBuildTypes()
    let buildTypes = try parseBuildTypes(from: data)
    
    cachedBuildTypes = buildTypes
    buildTypesCache.removeAll()
    buildTypeURLs.removeAll()
    vcsRootsCache.removeAll()
    
    try await withThrowingTaskGroup(of: Void.self) {
      group in
      for buildType in buildTypes {
        group.addTask {
          let data = try await self.fetchBuildType(id: buildType.id)
          try self.parseBuildTypeDetail(from: data)
        }
      }
      try await group.waitForAll()
    }
  }
  
  private func parseBuildTypeDetail(from data: Data) throws
  {
    let xml = try XMLDocument(data: data)
    guard let buildType = xml.rootElement() ?? xml.children?.first as? XMLElement
    else { throw ParseError.missingRoot }
    
    guard let buildTypeID = buildType.attribute(forName: "id")?.stringValue
    else { throw ParseError.missingBuildTypes }
    
    let name = buildType.attribute(forName: "name")?.stringValue ?? ""
    let projectName = buildType.attribute(forName: "projectName")?.stringValue ?? ""
    
    // Extract VCS root entries
    let rootEntries = buildType.elements(forName: "vcs-root-entries").first
    let vcsIDs = rootEntries?.childrenAttributes("id") ?? []
    var urls: [URL] = []
    
    for id in vcsIDs {
      if let url = vcsRootURLSnapshot(for: id) {
        urls.append(url)
      }
    }
    
    cachedBuildTypes.removeAll { $0.id == buildTypeID }
    cachedBuildTypes.append(BuildType(id: buildTypeID,
                                      name: name,
                                      projectName: projectName))
    buildTypeURLs[buildTypeID] = urls
  }
  
  // Test helpers
  func cachedBuildTypesSnapshot() -> [BuildType]
  { cachedBuildTypes }
  
  func buildTypeURLsSnapshot(for id: String) -> [URL]?
  { buildTypeURLs[id] }
  
  func vcsRootURLSnapshot(for id: String) -> URL?
  { vcsRootMap[id] }
  
  func branchSpecSnapshot(for id: String) -> BranchSpec?
  { vcsBranchSpecs[id] }
  
  func cachedVCSRoots(for buildType: String) -> [String]
  { vcsRootsCache[buildType] ?? [] }
  
  func cachedBranchSpec(for vcsRootID: String) -> BranchSpec?
  { vcsBranchSpecs[vcsRootID] }
}
