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
  
  init?(user: String, password: String, baseURL: String?) {
    authenticationStatus = .NotStarted
    
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
  func attemptAuthentication(path: String)
  {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    
    authenticationStatus = .InProgress
    
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
  }
  
  // For subclasses to override when more data needs to be downloaded.
  func didAuthenticate()
  {
  }
}


class XTTeamCityAPI : XTBasicAuthService, XTServiceAPI {
  
  var type: AccountType { return .TeamCity }
  
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
  
  override init?(user: String, password: String, baseURL: String?)
  {
    guard let baseURL = baseURL,
          let fullBaseURL = NSURLComponents(string: baseURL)
    else { return nil }
    
    fullBaseURL.path = "httpAuth/app/rest"
    
    super.init(user: user, password: password, baseURL: fullBaseURL.string)
    
    configureTransformer("**/properties/*") {
      (content: NSData, entity) -> String? in
      return String(data: content, encoding: NSUTF8StringEncoding)
    }
    configureTransformer("**") { (content: NSData, entity) -> AnyObject? in
      return (try? NSXMLDocument(data: content, options: 0)) ?? content
    }
    
    attemptAuthentication("")  // The base URL makes a good test.
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
  
  /// A resource for the repo URL of a VCS root. This will be just the URL,
  /// not wrapped in XML.
  func vcsRootURL(vcsRoodID: String) -> Resource
  {
    return resource("vcs-roots/id:\(vcsRoodID)/properties/url")
  }
  
  var buildTypes: Resource
  {
    return resource("buildTypes")
  }
}

// MARK: VCS

extension XTTeamCityAPI {
  
  override func didAuthenticate()
  {
    // - Get VCS roots, build repo URL -> vcs-root id map.
    vcsRoots.useData(self) { (data) in
      guard let xml = data.content as? NSXMLDocument
      else {
        NSLog("Couldn't parse vcs-roots xml")
        self.buildTypesStatus = .Failed(nil)
        return
      }
      self.parseVCSRoots(xml)
    }
  }
  
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
            let url = element.attributeForName("href")?.stringValue
      else {
        NSLog("Couldn't parse build type: \(type)")
        self.buildTypesStatus = .Failed(nil)
        return
      }
      resource(url).useData(self, closure: { (data) in
        waitingTypeCount -= 1
        
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
      
      if var buildTypeURLs = vcsBuildTypes[vcsID] {
        // Modify and put it back because Array is a value type
        buildTypeURLs.append(vcsURL)
        vcsBuildTypes[vcsID] = buildTypeURLs
      }
      else {
        vcsBuildTypes[vcsID] = [vcsURL]
      }
    }
    buildTypesStatus = .Done
  }
}

// Look up:
// - /httpAuth/app/rest/builds?locator=running:any,
//    buildType:\(buildType),branch:\(branch)
// - Returns a list of <build href=".."/>, retrieve those
