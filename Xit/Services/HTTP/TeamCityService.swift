import Foundation
import XitGit

final class TeamCityService: BaseHTTPService
{
  nonisolated static let rootPath = TeamCity.rootPath
  
  private struct CanonicalRepoID: Hashable
  {
    let host: String
    let path: String
  }
  
  private struct ParsedVCSRoot
  {
    enum Entry
    {
      case url(URL)
      case branchSpec(BranchSpec)
    }
    
    let id: String
    let entry: Entry
  }
  
  enum ParseError: Error
  {
    case invalidXML
    case missingRoot
    case missingBuildTypes
    case missingBuilds
    case missingVCSRootID
  }
  
  private var vcsRootMap: [String: URL] = [:]
  private var vcsBranchSpecs: [String: BranchSpec] = [:]
  private var buildTypeURLs: [String: [URL]] = [:]
  private var buildTypesCache: [String: [String]] = [:]
  private var vcsRootsCache: [String: [String]] = [:]
  private var cachedBuildTypes: [BuildType] = []
  
  let cacheLock = NSLock()
  
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
    let endpoint = Endpoint(baseURL: account.location,
                            path: Self.rootPath + "/builds/?locator=" + locator,
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
  
  func fetchBuildStatus(href: String) async throws -> Data
  {
    try await fetchBuild(href: href)
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
  
  func fetchBuildType(id: String) async throws -> Data
  {
    let endpoint = Endpoint(baseURL: account.location,
                            path: Self.rootPath + "/buildTypes/id:\(id)",
                            method: .get)
    return try await networkService.request(endpoint)
  }
  
  func loadBuildTypes() async throws -> [BuildType]
  {
    try parseBuildTypes(from: await fetchBuildTypes())
  }
  
  func loadBuilds(buildTypeID: String, branch: String? = nil) async throws -> [TeamCity.Build]
  {
    try parseBuilds(from: await fetchBuilds(buildTypeID: buildTypeID, branch: branch))
  }
  
  /// Load VCS roots and populate URL + branch spec caches.
  func loadVCSRoots() async throws
  {
    let listData = try await fetchVCSRoots()
    let xml = try XMLDocument(data: listData)
    guard let root = xml.rootElement()
    else { throw ParseError.missingRoot }
    
    let rootIDs = root.childrenAttributes("id")
    serviceLogger.debug("TeamCity loading \(rootIDs.count) VCS roots from \(self.account.location.absoluteString, privacy: .public)")
    
    let parsedRoots = try await withThrowingTaskGroup(of: [ParsedVCSRoot].self) {
      group in
      for rootID in rootIDs {
        group.addTask {
          let data = try await self.fetchVCSRoot(id: rootID)
          let xml = try XMLDocument(data: data)
          
          return self.parseVCSRoot(xml: xml, vcsRootID: rootID)
        }
      }
      
      var results: [ParsedVCSRoot] = []
      for try await parsed in group {
        results.append(contentsOf: parsed)
      }
      return results
    }
    
    cacheLock.withLock {
      self.vcsRootMap.removeAll()
      self.vcsBranchSpecs.removeAll()
      for parsed in parsedRoots {
        switch parsed.entry {
          case .url(let url):
            self.vcsRootMap[parsed.id] = url
          case .branchSpec(let branchSpec):
            self.vcsBranchSpecs[parsed.id] = branchSpec
        }
      }
    }
    
    for parsed in parsedRoots {
      switch parsed.entry {
        case .url(let url):
          serviceLogger.debug("TeamCity cached VCS root URL for \(parsed.id, privacy: .public): \(url.absoluteString, privacy: .public)")
        case .branchSpec:
          serviceLogger.debug("TeamCity cached branch spec for \(parsed.id, privacy: .public)")
      }
    }
  }
  
  func refreshMetadata() async
  {
    await MainActor.run { self.buildTypesStatus = .inProgress }
    serviceLogger.debug("TeamCity metadata refresh started for \(self.account.location.absoluteString, privacy: .public)")
    
    do {
      try await loadVCSRoots()
      try await refreshBuildTypes()
      await MainActor.run { self.buildTypesStatus = .done }
      serviceLogger.debug("TeamCity metadata refresh finished successfully for \(self.account.location.absoluteString, privacy: .public)")
    }
    catch {
      await MainActor.run { self.buildTypesStatus = .failed(error) }
      serviceLogger.debug("TeamCity metadata refresh failed for \(self.account.location.absoluteString, privacy: .public): \(String(describing: error), privacy: .public)")
    }
  }
  
  func buildType(id: String) async -> BuildType?
  {
    cacheLock.withLock { cachedBuildTypes.first { $0.id == id } }
  }
  
  func buildTypesForRemote(_ remoteURLString: String) async -> [String]
  {
    if let cached = buildTypesCache[remoteURLString] {
      serviceLogger.debug("TeamCity build types cache hit for remote \(remoteURLString, privacy: .public): \(cached, privacy: .public)")
      return cached
    }
    
    let normalizedRemoteString = normalizedRemoteURLString(remoteURLString)
    let remoteID = canonicalRepoID(from: remoteURLString)
    if remoteID == nil, normalizedRemoteString == nil {
      serviceLogger.debug("TeamCity could not canonicalize or normalize remote URL string \(remoteURLString, privacy: .public)")
      return []
    }
    
    let result = cacheLock.withLock {
      buildTypeURLs.keys.filter {
        buildType in
        buildTypeURLs[buildType]?.contains {
          url in
          if let remoteID, canonicalRepoID(from: url) == remoteID {
            return true
          }
          guard let normalizedRemoteString,
                let normalizedCandidate = normalizedRemoteURLString(url.absoluteString)
          else { return false }
          return normalizedCandidate == normalizedRemoteString
        } ?? false
      }
    }
    
    buildTypesCache[remoteURLString] = result
    if let remoteID {
      let canonicalDescription = remoteID.host + "/" + remoteID.path
      serviceLogger.debug("TeamCity matched build types \(result, privacy: .public) for remote \(remoteURLString, privacy: .public) canonical \(canonicalDescription, privacy: .public)")
    }
    else {
      serviceLogger.debug("TeamCity matched build types \(result, privacy: .public) for normalized remote \(normalizedRemoteString ?? remoteURLString, privacy: .public)")
    }
    return result
  }
  
  func displayName(for branch: LocalBranchRefName, buildType: String) async -> String?
  {
    let vcsRootIDs = cachedVCSRoots(for: buildType)
    if vcsRootIDs.isEmpty {
      return BranchSpec.defaultSpec().match(branch: branch.fullPath)
    }
    
    for vcsRootID in vcsRootIDs {
      if let matched = cachedBranchSpec(for: vcsRootID)?.match(branch: branch.fullPath) {
        return matched
      }
    }
    
    return BranchSpec.defaultSpec().match(branch: branch.fullPath)
  }
  
  private func refreshBuildTypes() async throws
  {
    let buildTypes = try await loadBuildTypes()
    serviceLogger.debug("TeamCity parsed \(buildTypes.count) build types from metadata refresh")
    
    cacheLock.withLock {
      self.cachedBuildTypes = buildTypes
      self.buildTypesCache.removeAll()
      self.buildTypeURLs.removeAll()
      self.vcsRootsCache.removeAll()
    }
    
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
  
  private func parseBuildTypes(from data: Data) throws -> [BuildType]
  {
    let xml = try XMLDocument(data: data)
    guard let root = xml.rootElement() ?? xml.children?.first as? XMLElement
    else { throw ParseError.missingRoot }
    guard root.name == "buildTypes"
    else { throw ParseError.missingBuildTypes }
    
    let buildTypes = root.elements(forName: "buildType").map {
      element in
      BuildType(id: element.attribute(forName: "id")?.stringValue ?? "",
                name: element.attribute(forName: "name")?.stringValue ?? "",
                projectName: element.attribute(forName: "projectName")?.stringValue ?? "")
    }
    return buildTypes.filter { !$0.id.isEmpty }
  }
  
  private func parseBuilds(from data: Data) throws -> [TeamCity.Build]
  {
    let xml = try XMLDocument(data: data)
    guard let root = xml.rootElement() ?? xml.children?.first as? XMLElement
    else { throw ParseError.missingRoot }
    
    let elements: [XMLElement]
    switch root.name {
      case "build":
        elements = [root]
      case "builds":
        elements = root.elements(forName: "build")
      default:
        throw ParseError.missingBuilds
    }
    
    return elements.compactMap(TeamCity.Build.init(element:))
  }
  
  private func parseVCSRoot(xml: XMLDocument, vcsRootID: String) -> [ParsedVCSRoot]
  {
    guard let root = xml.rootElement() ?? xml.children?.first as? XMLElement
    else { return [] }
    let resolvedID = root.attribute(forName: "id")?.stringValue ?? vcsRootID
    
    let properties = root.elements(forName: "properties").first?.elements(forName: "property") ?? []
    var parsed: [ParsedVCSRoot] = []
    
    for property in properties {
      let name = property.attribute(forName: "name")?.stringValue
      let value = property.attribute(forName: "value")?.stringValue
      
      switch name {
        case "url":
          if let value, let url = URL(string: value) {
            parsed.append(ParsedVCSRoot(id: resolvedID, entry: .url(url)))
          }
        case "teamcity:branchSpec":
          guard let value else { continue }
          let rules = value
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
          if let branchSpec = BranchSpec(ruleStrings: rules) {
            parsed.append(ParsedVCSRoot(id: resolvedID, entry: .branchSpec(branchSpec)))
          }
        default:
          continue
      }
    }
    
    return parsed
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
    let vcsIDs = buildType.elements(forName: "vcs-root-entries").first?.childrenAttributes("id") ?? []
    
    var urls: [URL] = []
    for id in vcsIDs {
      if let url = vcsRootURLSnapshot(for: id) {
        urls.append(url)
      }
      else {
        serviceLogger.debug("TeamCity build type \(buildTypeID, privacy: .public) referenced VCS root \(id, privacy: .public) without cached URL")
      }
    }
    
    cacheLock.withLock {
      self.cachedBuildTypes.removeAll { $0.id == buildTypeID }
      self.cachedBuildTypes.append(BuildType(id: buildTypeID,
                                             name: name,
                                             projectName: projectName))
      self.buildTypeURLs[buildTypeID] = urls
      self.vcsRootsCache[buildTypeID] = vcsIDs
    }
    
    serviceLogger.debug("TeamCity cached build type \(buildTypeID, privacy: .public) with VCS roots \(vcsIDs, privacy: .public) and VCS URLs \(urls.map(\.absoluteString), privacy: .public)")
  }
  
  private func canonicalRepoID(from url: URL) -> CanonicalRepoID?
  {
    canonicalRepoID(from: url.absoluteString)
  }
  
  private func canonicalRepoID(from remote: String) -> CanonicalRepoID?
  {
    let trimmed = remote.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    
    if let scpID = canonicalSCPRepoID(from: trimmed) {
      return scpID
    }
    guard let url = URL(string: trimmed) else { return nil }
    
    let normalizedHost = normalizedRepoHost(url.host)
    let path = normalizedRepoPath(url.path)
    guard let normalizedHost, let path else { return nil }
    
    return CanonicalRepoID(host: normalizedHost, path: path)
  }
  
  private func canonicalSCPRepoID(from remote: String) -> CanonicalRepoID?
  {
    guard !remote.contains("://"),
          let atIndex = remote.firstIndex(of: "@"),
          let colonIndex = remote[atIndex...].firstIndex(of: ":")
    else { return nil }
    
    let hostPart = String(remote[remote.index(after: atIndex)..<colonIndex])
    let pathPart = String(remote[remote.index(after: colonIndex)...])
    guard let host = normalizedRepoHost(hostPart),
          let path = normalizedRepoPath(pathPart)
    else { return nil }
    
    return CanonicalRepoID(host: host, path: path)
  }
  
  private func normalizedRepoHost(_ host: String?) -> String?
  {
    guard let host else { return nil }
    
    switch host.lowercased() {
      case "ssh.github.com":
        return "github.com"
      default:
        return host.lowercased()
    }
  }
  
  private func normalizedRepoPath(_ path: String) -> String?
  {
    let trimmed = path
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      .replacingOccurrences(of: #"/+"#, with: "/", options: .regularExpression)
    guard !trimmed.isEmpty else { return nil }
    
    let withoutGitSuffix: String
    if trimmed.lowercased().hasSuffix(".git") {
      withoutGitSuffix = String(trimmed.dropLast(4))
    }
    else {
      withoutGitSuffix = trimmed
    }
    
    let components = withoutGitSuffix.split(separator: "/", omittingEmptySubsequences: true)
    guard components.count >= 2 else { return nil }
    
    let owner = String(components[components.count - 2]).lowercased()
    let repo = String(components[components.count - 1]).lowercased()
    return owner + "/" + repo
  }
  
  private func normalizedRemoteURLString(_ remote: String) -> String?
  {
    let trimmed = remote.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: trimmed),
          var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return nil }
    
    components.scheme = components.scheme?.lowercased()
    components.host = components.host?.lowercased()
    components.user = nil
    components.password = nil
    components.fragment = nil
    components.query = nil
    components.percentEncodedQuery = nil
    
    let normalizedPath = normalizedPathString(components.percentEncodedPath)
    components.percentEncodedPath = normalizedPath
    
    return components.string
  }
  
  private func normalizedPathString(_ path: String) -> String
  {
    let collapsed = path
      .replacingOccurrences(of: #"/+"#, with: "/", options: .regularExpression)
    guard !collapsed.isEmpty else { return "/" }
    
    var normalized = collapsed.hasPrefix("/") ? collapsed : "/" + collapsed
    if normalized.count > 1, normalized.hasSuffix("/") {
      normalized.removeLast()
    }
    return normalized
  }
  
  // Test helpers
  func cachedBuildTypesSnapshot() -> [BuildType]
  { cacheLock.withLock { cachedBuildTypes } }
  
  func buildTypeURLsSnapshot(for id: String) -> [URL]?
  { cacheLock.withLock { buildTypeURLs[id] } }
  
  func vcsRootURLSnapshot(for id: String) -> URL?
  { cacheLock.withLock { vcsRootMap[id] } }
  
  func branchSpecSnapshot(for id: String) -> BranchSpec?
  { cacheLock.withLock { vcsBranchSpecs[id] } }
  
  func cachedVCSRoots(for buildType: String) -> [String]
  { cacheLock.withLock { vcsRootsCache[buildType] ?? [] } }
  
  func cachedBranchSpec(for vcsRootID: String) -> BranchSpec?
  { cacheLock.withLock { vcsBranchSpecs[vcsRootID] } }
}

extension TeamCityService: BuildStatusDisplayService {}
