import Foundation
@preconcurrency import Siesta
import Combine

protocol BuildStatusService: AnyObject
{
  func displayName(for branch: LocalBranchRefName, buildType: String) -> String?
  /// Branch name is supplied as a plain string because it could be a display name
  @MainActor
  func buildStatus(_ branch: String, buildType: String) -> Resource
  
  // TeamCity-specific stuff that should be abstrated somehow
  var vcsBranchSpecs: [String: BranchSpec] { get }
  
  func vcsRootsForBuildType(_ buildType: String) -> [String]
  func buildType(id: String) -> BuildType?
  func buildTypesForRemote(_ remoteURLString: String) -> [String]
}

/// API for getting TeamCity build information.
final class TeamCityAPI: BasicAuthService, ServiceAPI, BuildStatusService
{
  enum ParseStep
  {
    case vcsRoots, buildTypes, buildType
  }
  
  enum Error: Swift.Error
  {
    case vcsRoots
    case parseFailure(ParseStep)
    case findHrefs
    case firstBuildType
    case rootEntries
    case missingID
  }
  
  var type: AccountType { .teamCity }
  static let rootPath = "/httpAuth/app/rest"
  
  @Published
  fileprivate(set) var buildTypesStatus = Services.Status.notStarted
  
  /// Maps VCS root ID to repository URL.
  fileprivate(set) var vcsRootMap: [String: URL] = [:]
  /// Maps VCS root ID to branch specification.
  fileprivate(set) var vcsBranchSpecs: [String: BranchSpec] = [:]
  /// Maps built type IDs to lists of repository URLs.
  fileprivate(set) var buildTypeURLs: [String: [URL]] = [:]
  fileprivate(set) var cachedBuildTypes: [BuildType] = []
  /// Cached results for `buildTypesForRemote`
  private var buildTypesCache: [String: [String]] = [:]
  /// Cached results for `vcsRootsForBuildType`
  private var vcsRootsCache: [String: [String]] = [:]
  
  private let mutex = NSRecursiveLock()
  
  required init?(account: Account, password: String)
  {
    guard var fullBaseURL = URLComponents(url: account.location,
                                          resolvingAgainstBaseURL: false)
    else { return nil }
    
    fullBaseURL.path = TeamCityAPI.rootPath
    
    guard let location = fullBaseURL.url
    else { return nil }
    var account = account
    
    account.location = location
    
    super.init(account: account, password: password, authenticationPath: "/")
    
    configure(description: "xml") {
      $0.pipeline[.parsing].add(XMLResponseTransformer(),
                                contentTypes: [ "*/xml" ])
    }
  }
  
  /// Status of the most recent build of the given branch from any project
  /// and build type.
  @MainActor
  func buildStatus(_ branch: String, buildType: String) -> Resource
  {
    // Look up:
    // - builds?locator=running:any,
    //    buildType:\(buildType),branch:\(branch)
    // - Returns a list of <build href=".."/>, retrieve those
    // If we just pass this to resource(path:), the ? gets encoded.
    let href = "builds/?locator=running:any,branch:" +
               "\(branch),buildType:\(buildType)"
    let url = URL(string: href, relativeTo: baseURL)
    
    return self.resource(absoluteURL: url)
  }
  
  // Applies the given closure to the build statuses for the given branch and
  // build type, asynchronously if the data is not yet cached.
  @MainActor
  func enumerateBuildStatus(_ branch: LocalBranchRefName, buildType: String,
                            processor: @escaping ([String: String]) -> Void)
  {
    let statusResource = buildStatus(branch.fullPath, buildType: buildType)
    
    statusResource.useData(owner: self) {
      (data) in
      guard let xml = data.content as? XMLDocument,
            let builds = xml.children?.first?.children
      else { return }
      
      for build in builds {
        guard let buildElement = build as? XMLElement
        else { continue }
        
        processor(buildElement.attributesDict())
      }
    }
  }
  
  /// Use the branchSpecs to determine the display name for the given build type
  func displayName(for branch: LocalBranchRefName, buildType: String) -> String?
  {
    let vcsRoots = vcsRootsForBuildType(buildType)
    let displayNames = vcsRoots.compactMap
        { vcsBranchSpecs[$0]?.match(branch: branch.fullPath) }
    
    return displayNames.reduce(nil) {
      (shortest, name) -> String? in
      (shortest.map { $0.count < name.count } ?? false) ? shortest : name
    }
  }
  
  /// Use this instead of `Service.resource()` to ensure it runs on the main
  /// thread.
  @MainActor
  func pathResource(_ path: String) -> Resource
  { super.resource(path) }
  
  @MainActor
  var vcsRoots: Resource
  { pathResource("vcs-roots") }
  
  @MainActor
  var projects: Resource
  { pathResource("projects") }
  
  @MainActor
  var buildTypes: Resource
  { pathResource("buildTypes") }
  
  @MainActor
  /// A resource for the VCS root with the given ID.
  func vcsRoot(id: String) -> Resource
  {
    pathResource("vcs-roots/id:\(id)")
  }
  
  override func didAuthenticate(responseResource: Resource)
  {
    Task {
      // Get VCS roots, build repo URL -> vcs-root id map.
      do {
        let data = try await Signpost.interval(.teamCityQuery,
                                               call: { try await vcsRoots.data })
        guard let xml = data.content as? XMLDocument
        else {
          throw Error.vcsRoots
        }
        try await Signpost.interval(.teamCityProcess) {
          try await self.parseVCSRoots(xml)
        }
      }
      catch let error {
        self.buildTypesStatus = .failed(error)
      }
    }
  }
  
  // MARK: TeamCity
  
  // Calling this buildTypes(forRemote:) would conflict with the buildTypes var.
  /// Returns all the build types that use the given remote.
  func buildTypesForRemote(_ remoteURLString: String) -> [String]
  {
    if let cached = buildTypesCache[remoteURLString] {
      return cached
    }
    
    guard let remoteURL = URL(string: remoteURLString)
    else { return [] }
    func matchHostPath(_ url: URL) -> Bool
    {
      return remoteURL.host == url.host &&
             remoteURL.path == url.path
    }
    
    let result = buildTypeURLs.keys.filter {
      (key) in
      buildTypeURLs[key].map {
        (urls) in
        urls.contains { matchHostPath($0) }
      } ?? false
    }
    
    buildTypesCache[remoteURLString] = result
    return result
  }
  
  
  /// Returns a cached build type with a matching ID
  func buildType(id: String) -> BuildType?
  {
    return cachedBuildTypes.first { $0.id == id }
  }
  
  /// Returns the VCS root IDs that use the given build type.
  func vcsRootsForBuildType(_ buildType: String) -> [String]
  {
    if let cached = vcsRootsCache[buildType] {
      return cached
    }
    
    guard let urls = buildTypeURLs[buildType]
    else { return [] }
    let result = vcsRootMap.compactMap {
      (vcsRoot, rootURL) in
      urls.contains(rootURL) ? vcsRoot : nil
    }
    
    vcsRootsCache[buildType] = result
    return result
  }
  
  /// Parses the list of VCS roots, collecting their repository URLs.
  /// Once all repo URLs have been logged, it moves on to reading build types.
  func parseVCSRoots(_ xml: XMLDocument) async throws
  {
    guard let vcsIDs = xml.rootElement()?.childrenAttributes("id")
    else {
      throw Error.parseFailure(.vcsRoots)
    }
    
    buildTypesCache.removeAll()
    vcsRootMap.removeAll()
    vcsRootsCache.removeAll()
    vcsBranchSpecs.removeAll()
    
    try await withThrowingTaskGroup(of: Void.self) {
      (taskGroup) in
      for rootID in vcsIDs {
        let rootResource = await vcsRoot(id: rootID)
        
        taskGroup.addTask {
          let data = try await rootResource.data
          
          if let xmlData = data.content as? XMLDocument {
            self.parseVCSRoot(xml: xmlData, vcsRootID: rootID)
          }
        }
      }
      // Explicitly wait to get errors thrown from tasks
      try await taskGroup.waitForAll()
    }
    try await getBuildTypes()
  }
  
  /// Parses the data for an individual VCS root.
  func parseVCSRoot(xml: XMLDocument, vcsRootID: String)
  {
    guard let properties = xml.rootElement()?.elements(forName: "properties")
                              .first,
          let propertiesChildren = properties.children
    else { return }
    
    for property in propertiesChildren {
      guard let propertyElement = property as? XMLElement,
            let name = propertyElement.attribute(forName: "name")?.stringValue,
            let value = propertyElement.attribute(forName: "value")?.stringValue
      else { continue }
      
      mutex.withLock {
        switch name {
          case "url":
            vcsRootMap[vcsRootID] = URL(string: value)
          case "teamcity:branchSpec":
            let specLines = value.components(separatedBy: .whitespacesAndNewlines)
            
            if let branchSpec = BranchSpec(ruleStrings: specLines) {
              vcsBranchSpecs[vcsRootID] = branchSpec
            }
          default:
            break
        }
      }
    }
  }
  
  /// Initiates the request for the list of build types.
  func getBuildTypes() async throws
  {
    let data = try await buildTypes.data
    guard let xml = data.content as? XMLDocument
    else {
      throw Error.parseFailure(.buildTypes)
    }
    guard let hrefs = xml.rootElement()?.childrenAttributes(Build.Attribute.href)
    else {
      throw Error.findHrefs
    }
    
    cachedBuildTypes.removeAll()
    try await withThrowingTaskGroup(of: Void.self) {
      (taskGroup) in
      for href in hrefs {
        let relativePath = href.droppingPrefix(TeamCityAPI.rootPath)
        
        taskGroup.addTask {
          let data = try await self.pathResource(relativePath).data
          guard let xml = data.content as? XMLDocument
          else {
            throw Error.parseFailure(.buildType)
          }
          
          try self.parseBuildType(xml)
        }
      }
      try await taskGroup.waitForAll()
    }
    // buildTypeStatus is observed by SwiftUI, so it must be published from
    // the main thread.
    Thread.syncOnMain {
      self.buildTypesStatus = .done
    }
  }
  
  /// Parses an individual build type to see which VCS roots it uses.
  func parseBuildType(_ xml: XMLDocument) throws
  {
    guard let buildType = xml.children?.first as? XMLElement
    else {
      throw Error.firstBuildType
    }
    
    let name = buildType.attribute(forName: "name")?.stringValue ?? "❎"
    
    guard let rootEntries = buildType.elements(forName: "vcs-root-entries").first
    else {
      throw Error.rootEntries
    }
    guard let buildTypeID = buildType.attribute(forName: "id")?.stringValue
    else {
      throw Error.missingID
    }
    
    let projectName = buildType.attribute(forName: "projectName")?.stringValue
    
    mutex.withLock {
      cachedBuildTypes.append(BuildType(id: buildTypeID,
                                        name: name,
                                        projectName: projectName ?? ""))
      
      let vcsIDs = rootEntries.childrenAttributes("id")
      let urls = vcsIDs.compactMap { vcsRootMap[$0] }
      
      buildTypeURLs[buildTypeID] = urls
    }
  }
}

protocol BuildStatusAccessor: AnyObject
{
  var servicesMgr: Services { get }
  var remoteMgr: (any RemoteManagement)! { get }
}

extension BuildStatusAccessor
{
  /// Returns the first TeamCity service that builds from the given repository,
  /// and a list of its build types.
  func matchBuildStatusService(_ remoteName: String)
    -> (BuildStatusService, [String])?
  {
    guard let remoteMgr = self.remoteMgr,
          let remote = remoteMgr.remote(named: remoteName),
          let remoteURL = remote.urlString
    else { return nil }
    
    return servicesMgr.buildStatusService(for: remoteURL)
  }
}

extension TeamCityAPI: RemoteService
{
  func match(remote: any Remote) -> Bool
  {
    guard let urlString = remote.url?.absoluteString
    else { return false }
    
    return !buildTypesForRemote(urlString).isEmpty
  }
}
