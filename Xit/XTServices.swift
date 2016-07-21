import Cocoa
import Siesta

extension Siesta.Resource {
  
  /// Either executes the closure with the resource's data, or schedules it
  /// to run later when the data is available.
  func useData(owner: AnyObject, closure: (Entity) -> ())
  {
    if let data = latestData {
      closure(data)
    }
    else {
      addObserver(owner: owner, closure: { (resource, event) in
        if let data = resource.latestData {
          closure(data)
        }
      })
      loadIfNeeded()
    }
  }
}

/// Manages and provides access to all service API instances.
class XTServices: NSObject {
  
  /// Status of server operations such as authentication.
  enum Status {
    case Unknown
    case NotStarted
    case InProgress
    case Done
    case Failed(ErrorType?)
  }
  
  static let services = XTServices()
  
  private var teamCityServices: [String: XTTeamCityAPI] = [:]
  
  /// Creates an API object for each account so they can start with
  /// authorization and other state info.
  func initializeServices()
  {
    for account in XTAccountsManager.manager.accounts(ofType: .TeamCity) {
      _ = teamCityAPI(account)
    }
  }
  
  private static func accountKey(account: Account) -> String
  {
    return "\(account.user)@\(account.location.host)"
  }
  
  /// Returns the TeamCity service object for the given account, or nil if
  /// the password cannot be found.
  func teamCityAPI(account: Account) -> XTTeamCityAPI?
  {
    let key = XTServices.accountKey(account)
  
    if let api = teamCityServices[key] {
      return api
    }
    else {
      guard let password = XTKeychain.findPassword(account.location,
                                                   account: account.user)
      else {
        NSLog("No password found for \(key)")
        return nil
      }
      
      guard let api = XTTeamCityAPI(user: account.user,
                                    password: password,
                                    baseURL: account.location.absoluteString)
      else { return nil }
      
      api.attemptAuthentication()
      teamCityServices[key] = api
      return api
    }
  }
}


/// Protocol to be implemented by all concrete API classes.
protocol XTServiceAPI {
  
  var type: AccountType { get }
  
}


/// Abstract service class that handles HTTP basic authentication.
class XTBasicAuthService : Service {
  
  static let AuthenticationStatusChangedNotification = "AuthStatusChanged"
  
  private(set) var authenticationStatus: XTServices.Status
  {
    didSet
    {
      NSNotificationCenter.defaultCenter().postNotificationName(
          XTBasicAuthService.AuthenticationStatusChangedNotification,
          object: self)
    }
  }
  private let authenticationPath: String
  
  init?(user: String, password: String, baseURL: String?,
        authenticationPath: String) {
    self.authenticationStatus = .NotStarted
    self.authenticationPath = authenticationPath
    
    super.init(baseURL: baseURL)
  
    if !updateAuthentication(user, password: password) {
      return nil
    }
  }
  
  /// Re-generates the authentication header with the new credentials.
  func updateAuthentication(user: String, password: String) -> Bool
  {
    if let data = "\(user):\(password)"
      .dataUsingEncoding(NSUTF8StringEncoding)?
      .base64EncodedStringWithOptions([]) {
      configure { (builder) in
        builder.config.headers["Authorization"] = "Basic \(data)"
        builder.config.beforeStartingRequest { (resource, request) in
          request.onFailure { (error) in
            NSLog("Request error: \(error.userMessage) \(resource.url)")
          }
        }
      }
      return true
    }
    else {
      NSLog("Couldn't construct auth header for \(user) @ \(baseURL)")
      return false
    }
  }
  
  /// Checks that the user and password are accepted by the server.
  func attemptAuthentication(path: String? = nil)
  {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    
    authenticationStatus = .InProgress
    
    let path = path ?? authenticationPath
    let authResource = resource(path)
    
    for request in authResource.allRequests {
      request.cancel()
    }
    authResource.addObserver(owner: self) {
      (resource, event) in
      switch event {

        case .NewData, .NotModified:
          self.authenticationStatus = .Done
          self.didAuthenticate()

        case .Error:
          guard let error = resource.latestError
          else {
            NSLog("Error event with no error")
            return
          }
          
          if !(error.cause is Error.Cause.RequestCancelled) {
            self.authenticationStatus = .Failed(error)
          }

        default:
          break
      }
    }
    // Use a custom request to skip the XML transformer
    authResource.load(usingRequest: authResource.request(.GET))
  }
  
  // For subclasses to override when more data needs to be downloaded.
  func didAuthenticate()
  {
  }
}


private func XMLResponseTransformer(
    transformErrors: Bool = true) -> Siesta.ResponseTransformer
{
  return Siesta.ResponseContentTransformer(transformErrors: transformErrors) {
    (content: NSData, entity: Siesta.Entity) throws -> NSXMLDocument in
    return try NSXMLDocument(data: content, options: 0)
  }
}


class XTTeamCityAPI : XTBasicAuthService, XTServiceAPI {
  
  var type: AccountType { return .TeamCity }
  static let rootPath = "/httpAuth/app/rest"
  
  enum BuildStatus {
    case Unknown
    case Succeded
    case Failed(String)  // Failure reason
    case Running(Float)  // Percentage complete
  }
  
  private(set) var buildTypesStatus = XTServices.Status.NotStarted
  
  /// Maps VCS root ID to repository URL.
  var vcsRootMap = [String: String]()
  var vcsBuildTypes = [String: [String]]()
  
  init?(user: String, password: String, baseURL: String?)
  {
    guard let baseURL = baseURL,
          let fullBaseURL = NSURLComponents(string: baseURL)
    else { return nil }
    
    fullBaseURL.path = XTTeamCityAPI.rootPath
    
    super.init(user: user, password: password, baseURL: fullBaseURL.string,
               authenticationPath: "/")
    
    configure(description: "xml") {
      $0.config.pipeline[.parsing].add(XMLResponseTransformer(),
                                       contentTypes: [ "*/xml" ])
    }
  }
  
  /// Status of the most recent build of the given branch from any project
  /// and build type.
  func buildStatus(branch: String) -> Resource
  {
    return resource("builds/running:any,branch:\(branch)")
  }
  
  var vcsRoots: Resource
  { return resource("vcs-roots") }
  
  var projects: Resource
  { return resource("projects") }
  
  var buildTypes: Resource
  { return resource("buildTypes") }
  
  /// A resource for the repo URL of a VCS root. This will be just the URL,
  /// not wrapped in XML.
  func vcsRootURL(vcsRoodID: String) -> Resource
  {
    return resource("vcs-roots/id:\(vcsRoodID)/properties/url")
  }
  
  override func didAuthenticate()
  {
    // - Get VCS roots, build repo URL -> vcs-root id map.
    vcsRoots.useData(self) { (data) in
      guard let xml = data.content as? NSXMLDocument
      else {
        NSLog("Couldn't parse vcs-roots xml")
        self.buildTypesStatus = .Failed(nil)  // TODO: ParseError type
        return
      }
      self.parseVCSRoots(xml)
    }
  }
}

// MARK: VCS

extension XTTeamCityAPI {
  
  /// Returns all the build types that use the given remote.
  func buildTypes(remoteURL: NSString) -> [String]
  {
    var result = [String]()
    
    for (buildType, urls) in vcsBuildTypes {
      if !urls.filter({ $0 == remoteURL }).isEmpty {
        result.append(buildType)
      }
    }
    return result
  }
  
  private func parseVCSRoots(xml: NSXMLDocument)
  {
    guard let vcsRoots = xml.children?.first?.children
    else {
      NSLog("Couldn't parse vcs-roots")
      self.buildTypesStatus = .Failed(nil)
      return
    }
    
    var waitingRootCount = vcsRoots.count
    
    vcsRootMap.removeAll()
    for vcsRoot in vcsRoots {
      guard let element = vcsRoot as? NSXMLElement,
            let rootID = element.attributeForName("id")?.stringValue
      else {
        NSLog("Couldn't parse vcs-roots")
        self.buildTypesStatus = .Failed(nil)
        return
      }
      
      let repoResource = self.vcsRootURL(rootID)
      
      repoResource.useData(self, closure: { (data) in
        if let repoURL = data.content as? String {
          self.vcsRootMap[rootID] = repoURL
        }
        waitingRootCount -= 1
        if (waitingRootCount == 0) {
          self.getBuildTypes()
        }
      })
    }
  }
  
  private func getBuildTypes()
  {
    buildTypes.useData(self) { (data) in
      guard let xml = data.content as? NSXMLDocument
      else {
        NSLog("Couldn't parse build types xml")
        self.buildTypesStatus = .Failed(nil)
        return
      }
      self.parseBuildTypes(xml)
    }
  }
  
  private func parseBuildTypes(xml: NSXMLDocument)
  {
    guard let buildTypesList = xml.rootElement()?.children
    else {
      NSLog("Couldn't parse build types")
      self.buildTypesStatus = .Failed(nil)
      return
    }
    
    var waitingTypeCount = buildTypesList.count
    
    for type in buildTypesList {
      guard let element = type as? NSXMLElement,
            let href = element.attributeForName("href")?.stringValue
      else {
        NSLog("Couldn't parse build type: \(type)")
        self.buildTypesStatus = .Failed(nil)
        return
      }
      
      let relativePath = href.stringByRemovingPrefix(XTTeamCityAPI.rootPath)
      
      resource(relativePath).useData(self, closure: { (data) in
        waitingTypeCount -= 1
        defer {
          if waitingTypeCount == 0 {
            self.buildTypesStatus = .Done
          }
        }
        
        guard let xml = data.content as? NSXMLDocument
        else {
          NSLog("Couldn't parse build type xml: \(data.content)")
          self.buildTypesStatus = .Failed(nil)
          return
        }
        
        self.parseBuildType(xml)
      })
    }
  }
  
  private func parseBuildType(xml: NSXMLDocument)
  {
    guard let buildType = xml.children?.first as? NSXMLElement,
          let rootEntries = buildType.elementsForName("vcs-root-entries").first
    else {
      NSLog("Couldn't find root entries: \(xml)")
      self.buildTypesStatus = .Failed(nil)
      return
    }
    guard let buildTypeID = buildType.attributeForName("id")?.stringValue
    else {
      NSLog("No ID for build type: \(xml)")
      return
    }
    guard let entriesChildren = rootEntries.children
    else { return }  // Empty list is not an error
    
    for entry in entriesChildren {
      guard let entryElement = entry as? NSXMLElement,
            let vcsID = entryElement.attributeForName("id")?.stringValue
      else { continue }
      guard let vcsURL = vcsRootMap[vcsID]
      else {
        NSLog("No match for VCS ID \(vcsID)")
        continue
      }
      
      if var buildTypeURLs = vcsBuildTypes[buildTypeID] {
        // Modify and put it back because Array is a value type
        buildTypeURLs.append(vcsURL)
        vcsBuildTypes[buildTypeID] = buildTypeURLs
      }
      else {
        vcsBuildTypes[buildTypeID] = [vcsURL]
      }
    }
  }
}

// Look up:
// - /httpAuth/app/rest/builds?locator=running:any,
//    buildType:\(buildType),branch:\(branch)
// - Returns a list of <build href=".."/>, retrieve those
