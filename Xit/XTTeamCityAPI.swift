import Foundation
import Siesta


/// API for getting TeamCity build information.
class XTTeamCityAPI : XTBasicAuthService, XTServiceAPI
{
  var type: AccountType { return .teamCity }
  static let rootPath = "/httpAuth/app/rest"
  
  struct Build
  {
    enum Status
    {
      case succeeded
      case failed
      case unknown
      
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
    
    struct Attribute
    {
      static let id = "id"
      static let buildType = "buildTypeId"
      static let buildNumber = "number"
      static let status = "status"
      static let state = "state"
      static let running = "running"
      static let percentage = "percentageComplete"
      static let branchName = "branchName"
      static let href = "href"
      static let webURL = "webUrl"
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
      
      self.buildType = attributes[Attribute.buildType]
      self.status = attributes[Attribute.status].flatMap { Status(string: $0) }
      self.state = attributes[Attribute.state].flatMap { State(string: $0) }
      self.url = attributes[Attribute.webURL].flatMap { URL(string: $0) }
    }
    
    init?(xml: XMLDocument)
    {
      guard let build = xml.rootElement()
      else { return nil }
      
      self.init(element: build)
    }
  }
  
  fileprivate(set) var buildTypesStatus = XTServices.Status.notStarted
  {
    didSet
    {
      if buildTypesStatus != oldValue &&
         buildTypesStatus == .done {
        NotificationCenter.default.post(
            name: NSNotification.Name.XTTeamCityStatusChanged,
            object: self)
      }
    }
  }
  
  /// Maps VCS root ID to repository URL.
  fileprivate(set) var vcsRootMap = [String: String]()
  /// Maps VCS root ID to branch specification.
  fileprivate(set) var vcsBranchSpecs = [String: BranchSpec]()
  /// Maps built type IDs to lists of repository URLs.
  fileprivate(set) var vcsBuildTypes = [String: [String]]()
  
  init?(user: String, password: String, baseURL: String?)
  {
    guard let baseURL = baseURL,
          var fullBaseURL = URLComponents(string: baseURL)
    else { return nil }
    
    fullBaseURL.path = XTTeamCityAPI.rootPath
    
    super.init(user: user, password: password,
               baseURL: fullBaseURL.string,
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
  
  /// A resource for the VCS root with the given ID.
  func vcsRoot(id: String) -> Resource
  {
    return resource("vcs-roots/id:\(id)")
  }
  
  override func didAuthenticate()
  {
    // Get VCS roots, build repo URL -> vcs-root id map.
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

  // MARK: TeamCity
  // This used to be in an extension but the compiler got confused.

  /// A branch specification describes which branches in a VCS are used,
  /// and how their names are displayed.
  public class BranchSpec
  {
    enum Inclusion
    {
      case include
      case exclude
    }
    
    /// An invididual matching rule in a branch specification.
    struct Rule
    {
      let inclusion: Inclusion
      let regex: NSRegularExpression
      
      init?(content: String)
      {
        let prefixEndIndex = content.index(content.startIndex,
                                           offsetBy: 2)
        
        switch content.substring(to: prefixEndIndex) {
          case "+:":
            self.inclusion = .include
          case "-:":
            self.inclusion = .exclude
          default:
            return nil
        }
        
        var substring = content.substring(from: prefixEndIndex)
        
        // Parentheses are needed to identify a range to be extracted.
        substring = substring.replacingOccurrences(of: "*", with: "(.+)")
        substring.insert("^", at: substring.startIndex)
      
        if let regex = try? NSRegularExpression(pattern: substring) {
          self.regex = regex
        }
        else {
          return nil
        }
      }
      
      func match(branch: String) -> String?
      {
        let stringRange = NSRange(location: 0, length: branch.utf8.count)
        guard let match = regex.firstMatch(in: branch, options: .anchored,
                                           range: stringRange)
        else { return nil }
        
        if match.numberOfRanges >= 2 {
          return (branch as NSString).substring(with: match.rangeAt(1))
        }
        return nil
      }
    }
    
    let rules: [Rule]
    
    init?(ruleStrings: [String])
    {
      self.rules = ruleStrings.flatMap { Rule(content: $0) }
      if self.rules.count == 0 {
        return nil
      }
    }
    
    class func defaultSpec() -> BranchSpec
    {
      return BranchSpec(ruleStrings: ["+:refs/heads/*"])!
    }
    
    /// If the given branch matches the rules, the display name is returned,
    /// otherwise nil.
    func match(branch: String) -> String?
    {
      for rule in rules {
        if let result = rule.match(branch: branch) {
          return rule.inclusion == .include ? result : nil
        }
      }
      return nil
    }
  }

  // Calling this buildTypes(forRemote:) would conflict with the buildTypes var.
  /// Returns all the build types that use the given remote.
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
  
  /// Returns the VCS root IDs that use the given build type.
  func vcsRootsForBuildType(_ buildType: String) -> [String]
  {
    var result = [String]()
    guard let urls = vcsBuildTypes[buildType]
    else { return result }
    
    for (vcsRoot, rootURL) in vcsRootMap {
      if urls.contains(rootURL) {
        result.append(vcsRoot)
      }
    }
    
    return result;
  }
  
  /// Parses the list of VCS roots, collecting their repository URLs.
  /// Once all repo URLs have been logged, it moves on to reading build types.
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
    vcsBranchSpecs.removeAll()
    for rootID in vcsIDs {
      let rootResource = vcsRoot(id: rootID)
      
      rootResource.useData(owner: self) {
        (data) in
        if let xmlData = data.content as? XMLDocument {
          self.parseVCSRoot(xml: xmlData, vcsRootID: rootID)
          waitingRootCount -= 1
          if (waitingRootCount == 0) {
            self.getBuildTypes()
          }
        }
      }
    }
  }
  
  /// Parses the data for an individual VCS root.
  private func parseVCSRoot(xml: XMLDocument, vcsRootID: String)
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
          vcsRootMap[vcsRootID] = value
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
  
  /// Parses the received list of build types. Once all have been parsed
  /// successfully, `buildTypesStatus` is set to `done`.
  private func parseBuildTypes(_ xml: XMLDocument)
  {
    guard let hrefs = xml.rootElement()?.childrenAttributes(Build.Attribute.href)
    else {
      NSLog("Couldn't get hrefs: \(xml)")
      return
    }
    
    var waitingTypeCount = hrefs.count
    
    for href in hrefs {
      let relativePath = href.removingPrefix(XTTeamCityAPI.rootPath)
      
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
  
  /// Parses an individual build type to see which VCS roots it uses.
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
