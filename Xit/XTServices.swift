import Cocoa
import Siesta

extension Siesta.Resource {
  
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
    }
  }
}

/// Manages and provides access to all service API instances.
class XTServices: NSObject {
  
  enum Status {
    case Authenticating
    case Authenticated
    case Downloading
    case Ready
    case FailedAuthentication(ErrorType?)
    case DownloadFailed(ErrorType?)
  }
  
  static let services = XTServices()
  
  var teamCityServices: [String: XTTeamCityAPI] = [:]
  
  static func accountKey(account: Account) -> String
  {
    return "\(account.user)@\(account.location.host)"
  }
  
  /// Returns the TeamCity service object for the given account, or nil if
  /// the psasword cannot be found.
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


/// Abstract service class that handles HTTP basic authentication.
class XTBasicAuthService : Service {
  
  var status: XTServices.Status
  
  init?(user: String, password: String, baseURL: String?) {
    status = .Authenticating
    
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
    
    status = .Authenticating
    
    let authResource = resource(path)
    
    for request in authResource.allRequests {
      request.cancel()
    }
    authResource.addObserver(owner: self) {
      (resource, event) in
      switch event {

        case .NewData, .NotModified:
          self.status = .Authenticated
          self.didAuthenticate()

        case .Error:
          guard let error = resource.latestError
          else {
            NSLog("Error event with no error")
            return
          }
          
          if !(error.cause is Error.Cause.RequestCancelled) {
            self.status = .FailedAuthentication(error)
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


class XTTeamCityAPI : XTBasicAuthService {
  
  enum BuildStatus {
    case Unknown
    case Succeded
    case Failed(String)  // Failure reason
    case Running(Float)  // Percentage complete
  }
  
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
    
    attemptAuthentication("")
    //enabledLogCategories = LogCategory.detailed
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
        self.status = .DownloadFailed(nil)
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
      self.status = .DownloadFailed(nil)
      return
    }
    
    var waitingRootCount = vcsRoots.count
    
    vcsRootMap.removeAll()
    for vcsRoot in vcsRoots {
      guard let element = vcsRoot as? NSXMLElement,
            let rootID = element.attributeForName("id")?.stringValue
      else {
        NSLog("Couldn't parse vcs-roots")
        self.status = .DownloadFailed(nil)
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
        self.status = .DownloadFailed(nil)
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
      self.status = .DownloadFailed(nil)
      return
    }
    
    var waitingTypeCount = buildTypesList.count
    
    for type in buildTypesList {
      guard let element = type as? NSXMLElement,
            let url = element.attributeForName("href")?.stringValue
      else {
        NSLog("Couldn't parse build type: \(type)")
        self.status = .DownloadFailed(nil)
        return
      }
      resource(url).useData(self, closure: { (data) in
        waitingTypeCount -= 1
        
        guard let xml = data.content as? NSXMLDocument
        else {
          NSLog("Couldn't parse build type xml: \(data.content)")
          self.status = .DownloadFailed(nil)
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
      self.status = .DownloadFailed(nil)
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
    status = .Ready
  }
}

// Look up:
// - /httpAuth/app/rest/builds?locator=running:any,
//    buildType:\(buildType),branch:\(branch)
// - Returns a list of <build href=".."/>, retrieve those
