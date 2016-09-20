import Foundation
import Siesta


/// API for getting TeamCity build information.
class XTTeamCityAPI : XTBasicAuthService, XTServiceAPI
{
  var type: AccountType { return .teamCity }
  static let rootPath = "/httpAuth/app/rest"
  
  struct Build {
    enum Status
    {
      case succeeded
      case failed
      
      init?(string: String)
      {
        switch string {
          case "SUCCESS":
            self = .succeeded
          case "FAILURE":
            self = .failed
          default:
            return nil
        }
      }
    }
    
    enum State
    {
      case running
      case finished
      
      init?(string: String)
      {
        switch string {
          case "running":
            self = .running
          case "finished":
            self = .finished
          default:
            return nil
        }
      }
    }
    
    struct Attribute {
      static let ID = "id"
      static let BuildType = "buildTypeId"
      static let BuildNumber = "number"
      static let Status = "status"
      static let State = "state"
      static let Running = "running"
      static let Percentage = "percentageComplete"
      static let BranchName = "branchName"
      static let HRef = "href"
      static let WebURL = "webUrl"
    }
    
    let buildType: String?
    let status: Status?
    let state: State?
    let url: URL?
    
    init?(element buildElement: XMLElement)
    {
      guard buildElement.name == "build"
      else { return nil }
      
      let attributes = buildElement.attributesDict()
      
      self.buildType = attributes[Attribute.BuildType]
      self.status = attributes[Attribute.Status].flatMap { Status(string: $0) }
      self.state = attributes[Attribute.State].flatMap { State(string: $0) }
      self.url = attributes[Attribute.WebURL].flatMap { URL(string: $0) }
    }
    
    init?(xml: XMLDocument)
    {
      guard let build = xml.rootElement()
      else { return nil }
      
      self.init(element: build)
    }
  }
  
  fileprivate(set) var buildTypesStatus = XTServices.Status.notStarted
  
  /// Maps VCS root ID to repository URL.
  var vcsRootMap = [String: String]()
  /// Maps built type IDs to lists of repository URLs.
  var vcsBuildTypes = [String: [String]]()
  
  init?(user: String, password: String, baseURL: String?)
  {
    guard let baseURL = baseURL,
          var fullBaseURL = URLComponents(string: baseURL)
    else { return nil }
    
    fullBaseURL.path = XTTeamCityAPI.rootPath
    
    super.init(user: user, password: password, baseURL: fullBaseURL.string,
               authenticationPath: "/")
    
    configure(description: "xml") {
      $0.pipeline[.parsing].add(XMLResponseTransformer(),
                                       contentTypes: [ "*/xml" ])
    }
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
    let href = "builds/?locator=running:any,branch:\(branch),buildType:\(buildType)"
    let url = URL(string: href, relativeTo: baseURL)
    
    return self.resource(absoluteURL: url)
  }
  
  // Applies the given closure to the build statuses for the given branch and
  // build type, asynchronously if the data is not yet cached.
  func enumerateBuildStatus(_ branch: String, builtType: String,
                            processor: @escaping ([String: String]) -> Void)
  {
    let statusResource = buildStatus(branch, buildType: builtType)
    
    statusResource.useData(owner: self) { (data) in
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
  
  var vcsRoots: Resource
  { return resource("vcs-roots") }
  
  var projects: Resource
  { return resource("projects") }
  
  var buildTypes: Resource
  { return resource("buildTypes") }
  
  /// A resource for the repo URL of a VCS root. This will be just the URL,
  /// not wrapped in XML.
  func vcsRootURL(_ vcsRoodID: String) -> Resource
  {
    return resource("vcs-roots/id:\(vcsRoodID)/properties/url")
  }
  
  override func didAuthenticate()
  {
    // - Get VCS roots, build repo URL -> vcs-root id map.
    vcsRoots.useData(owner: self) { (data) in
      guard let xml = data.content as? XMLDocument
      else {
        NSLog("Couldn't parse vcs-roots xml")
        self.buildTypesStatus = .failed(nil)  // TODO: ParseError type
        return
      }
      self.parseVCSRoots(xml)
    }
  }
}

// MARK: VCS

extension XTTeamCityAPI
{
  /// Returns all the build types that use the given remote.
  // Calling it buildTypes(forRemote:) would conflict with the buildTypes var.
  func buildTypesForRemote(_ remoteURL: String) -> [String]
  {
    var result = [String]()
    
    for (buildType, urls) in vcsBuildTypes {
      if !urls.filter({ $0 == remoteURL }).isEmpty {
        result.append(buildType)
      }
    }
    return result
  }
  
  fileprivate func parseVCSRoots(_ xml: XMLDocument)
  {
    guard let vcsIDs = xml.rootElement()?.childrenAttributes("id")
    else {
      NSLog("Couldn't parse vcs-roots")
      self.buildTypesStatus = .failed(nil)
      return
    }
    
    var waitingRootCount = vcsIDs.count
    
    vcsRootMap.removeAll()
    for rootID in vcsIDs {
      let repoResource = self.vcsRootURL(rootID)
      
      repoResource.useData(owner: self) { (data) in
        if let repoURL = data.content as? String {
          self.vcsRootMap[rootID] = repoURL
        }
        waitingRootCount -= 1
        if (waitingRootCount == 0) {
          self.getBuildTypes()
        }
      }
    }
  }
  
  private func getBuildTypes()
  {
    buildTypes.useData(owner: self) { (data) in
      guard let xml = data.content as? XMLDocument
      else {
        NSLog("Couldn't parse build types xml")
        self.buildTypesStatus = .failed(nil)
        return
      }
      self.parseBuildTypes(xml)
    }
  }
  
  private func parseBuildTypes(_ xml: XMLDocument)
  {
    guard let hrefs = xml.rootElement()?.childrenAttributes(Build.Attribute.HRef)
    else {
      NSLog("Couldn't get hrefs: \(xml)")
      return
    }
    
    var waitingTypeCount = hrefs.count
    
    for href in hrefs {
      let relativePath = href.stringByRemovingPrefix(XTTeamCityAPI.rootPath)
      
      resource(relativePath).useData(owner: self, closure: { (data) in
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
      })
    }
  }
  
  private func parseBuildType(_ xml: XMLDocument)
  {
    guard let buildType = xml.children?.first as? XMLElement,
          let rootEntries = buildType.elements(forName: "vcs-root-entries").first
    else {
      NSLog("Couldn't find root entries: \(xml)")
      self.buildTypesStatus = .failed(nil)
      return
    }
    guard let buildTypeID = buildType.attribute(forName: "id")?.stringValue
    else {
      NSLog("No ID for build type: \(xml)")
      return
    }
    
    let vcsIDs = rootEntries.childrenAttributes("id")
    var buildTypeURLs = [String]()
    
    for vcsID in vcsIDs {
      guard let vcsURL = vcsRootMap[vcsID]
      else {
        NSLog("No match for VCS ID \(vcsID)")
        continue
      }
      
      buildTypeURLs.append(vcsURL)
    }
    vcsBuildTypes[buildTypeID] = buildTypeURLs
  }
}
