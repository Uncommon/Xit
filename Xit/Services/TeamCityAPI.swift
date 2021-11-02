import Foundation
import Siesta
import Combine

/// API for getting TeamCity build information.
final class TeamCityAPI: BasicAuthService, ServiceAPI
{
  var type: AccountType { .teamCity }
  static let rootPath = "/httpAuth/app/rest"

  @Published fileprivate(set) var buildTypesStatus = Services.Status.notStarted

  /// Maps VCS root ID to repository URL.
  fileprivate(set) var vcsRootMap = [String: URL]()
  /// Maps VCS root ID to branch specification.
  fileprivate(set) var vcsBranchSpecs = [String: BranchSpec]()
  /// Maps built type IDs to lists of repository URLs.
  fileprivate(set) var buildTypeURLs = [String: [URL]]()
  fileprivate(set) var cachedBuildTypes = [BuildType]()
  /// Cached results for `buildTypesForRemote`
  private var buildTypesCache: [String: [String]] = [:]
  /// Cached results for `vcsRootsForBuildType`
  private var vcsRootsCache: [String: [String]] = [:]
  
  init?(account: Account, password: String)
  {
    guard var fullBaseURL = URLComponents(url: account.location,
                                          resolvingAgainstBaseURL: false)
    else { return nil }
    
    fullBaseURL.path = TeamCityAPI.rootPath
    
    guard let location = fullBaseURL.url
    else { return nil }
    
    account.location = location
    
    super.init(account: account, password: password, authenticationPath: "/")
    
    configure(description: "xml") {
      $0.pipeline[.parsing].add(XMLResponseTransformer(),
                                contentTypes: [ "*/xml" ])
    }
  }
  
  static func service(for remoteURL: String) -> (TeamCityAPI, [String])?
  {
    guard !UserDefaults.standard.bool(forKey: "noServices")
    else { return nil }
    
    let accounts = AccountsManager.manager.accounts(ofType: .teamCity)
    let services = accounts.compactMap { Services.shared.teamCityAPI($0) }
    
    for service in services {
      let buildTypes = service.buildTypesForRemote(remoteURL)
      
      if !buildTypes.isEmpty {
        return (service, buildTypes)
      }
    }
    return nil
  }
  
  /// Status of the most recent build of the given branch from any project
  /// and build type.
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
  func enumerateBuildStatus(_ branch: String, buildType: String,
                            processor: @escaping ([String: String]) -> Void)
  {
    let statusResource = buildStatus(branch, buildType: buildType)
    
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
  func displayName(forBranch branch: String, buildType: String) -> String?
  {
    let vcsRoots = vcsRootsForBuildType(buildType)
    let displayNames = vcsRoots.compactMap
        { vcsBranchSpecs[$0]?.match(branch: branch) }
    
    return displayNames.reduce(nil) {
      (shortest, name) -> String? in
      (shortest.map { $0.count < name.count } ?? false)
          ? shortest : name
    }
  }
  
  var vcsRoots: Resource
  { resource("vcs-roots") }
  
  var projects: Resource
  { resource("projects") }
  
  var buildTypes: Resource
  { resource("buildTypes") }
  
  /// A resource for the VCS root with the given ID.
  func vcsRoot(id: String) -> Resource
  {
    return resource("vcs-roots/id:\(id)")
  }
  
  override func didAuthenticate(responseResource: Resource)
  {
    Signpost.intervalStart(.teamCityQuery)
    // Get VCS roots, build repo URL -> vcs-root id map.
    vcsRoots.useData(owner: self) {
      (data) in
      Signpost.intervalEnd(.teamCityQuery)
      guard let xml = data.content as? XMLDocument
      else {
        NSLog("Couldn't parse vcs-roots xml")
        self.buildTypesStatus = .failed(nil)  // TODO: ParseError type
        return
      }
      Signpost.interval(.teamCityProcess) {
        self.parseVCSRoots(xml)
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
      key in
      buildTypeURLs[key].map {
        urls in
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
  func parseVCSRoots(_ xml: XMLDocument)
  {
    guard let vcsIDs = xml.rootElement()?.childrenAttributes("id")
    else {
      NSLog("Couldn't parse vcs-roots")
      self.buildTypesStatus = .failed(nil)
      return
    }
    
    var waitingRootCount = vcsIDs.count

    buildTypesCache.removeAll()
    vcsRootMap.removeAll()
    vcsRootsCache.removeAll()
    vcsBranchSpecs.removeAll()
    for rootID in vcsIDs {
      let rootResource = vcsRoot(id: rootID)
      
      rootResource.useData(owner: self) {
        (data) in
        if let xmlData = data.content as? XMLDocument {
          self.parseVCSRoot(xml: xmlData, vcsRootID: rootID)
          waitingRootCount -= 1
          if waitingRootCount == 0 {
            self.getBuildTypes()
          }
        }
      }
    }
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
  
  /// Initiates the request for the list of build types.
  func getBuildTypes()
  {
    buildTypes.useData(owner: self) {
      (data) in
      guard let xml = data.content as? XMLDocument
      else {
        NSLog("Couldn't parse build types xml")
        self.buildTypesStatus = .failed(nil)
        return
      }
      self.parseBuildTypes(xml)
    }
  }
  
  /// Parses the received list of build types. Once all have been parsed
  /// successfully, `buildTypesStatus` is set to `done`.
  func parseBuildTypes(_ xml: XMLDocument)
  {
    guard let hrefs = xml.rootElement()?.childrenAttributes(Build.Attribute.href)
    else {
      NSLog("Couldn't get hrefs: \(xml)")
      return
    }
    
    var waitingTypeCount = hrefs.count
    
    cachedBuildTypes.removeAll()
    for href in hrefs {
      let relativePath = href.droppingPrefix(TeamCityAPI.rootPath)
      
      resource(relativePath).useData(owner: self) {
        (data) in
        waitingTypeCount -= 1
        defer {
          if waitingTypeCount == 0 {
            self.buildTypesStatus = .done
          }
        }
        
        guard let xml = data.content as? XMLDocument
        else {
          NSLog("Couldn't parse build type xml")
          self.buildTypesStatus = .failed(nil)
          return
        }
        
        self.parseBuildType(xml)
      }
    }
  }
  
  /// Parses an individual build type to see which VCS roots it uses.
  func parseBuildType(_ xml: XMLDocument)
  {
    guard let buildType = xml.children?.first as? XMLElement
    else {
      NSLog("Can't get first buildType element: \(xml)")
      return
    }

    let name = buildType.attribute(forName: "name")?.stringValue ?? "❎"

    guard let rootEntries = buildType.elements(forName: "vcs-root-entries").first
    else {
      self.buildTypesStatus = .failed(nil)
      return
    }
    guard let buildTypeID = buildType.attribute(forName: "id")?.stringValue
    else {
      NSLog("No ID for build type \(name)")
      return
    }

    let projectName = buildType.attribute(forName: "projectName")?.stringValue
    
    cachedBuildTypes.append(BuildType(id: buildTypeID,
                                      name: name,
                                      projectName: projectName ?? ""))
    
    let vcsIDs = rootEntries.childrenAttributes("id")
    let urls = vcsIDs.compactMap { vcsRootMap[$0] }

    buildTypeURLs[buildTypeID] = urls
  }
}

protocol TeamCityAccessor: AnyObject
{
  var remoteMgr: RemoteManagement! { get }
}

extension TeamCityAccessor
{
  /// Returns the first TeamCity service that builds from the given repository,
  /// and a list of its build types.
  func matchTeamCity(_ remoteName: String) -> (TeamCityAPI, [String])?
  {
    guard let remoteMgr = self.remoteMgr,
          let remote = remoteMgr.remote(named: remoteName),
          let remoteURL = remote.urlString
    else { return nil }
    
    return TeamCityAPI.service(for: remoteURL)
  }
}

extension TeamCityAPI: RemoteService
{
  func match(remote: Remote) -> Bool
  {
    guard let urlString = remote.url?.absoluteString
    else { return false }
    
    return !buildTypesForRemote(urlString).isEmpty
  }
}
