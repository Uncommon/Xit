import Cocoa
import Siesta

/// Manages and provides access to all service API instances.
class XTServices: NSObject {
  
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
  
  init?(user: String, password: String, baseURL: String?) {
    super.init(baseURL: baseURL)
  
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
    }
    else {
      NSLog("Couldn't construct auth header for \(user) @ \(baseURL)")
      return nil
    }
  }
  
}


class XTTeamCityAPI : XTBasicAuthService {
  
  enum BuildStatus {
    case Unknown
    case Succeded
    case Failed(String)  // Failure reason
    case Running(Float)  // Percentage complete
  }
  
  override init?(user: String, password: String, baseURL: String?)
  {
    super.init(user: user, password: password, baseURL: baseURL)
    
    configureTransformer("**/properties/*") {
      (content: NSData, entity) -> String? in
      return String(data: content, encoding: NSUTF8StringEncoding)
    }
    configureTransformer("**") { (content: NSData, entity) -> AnyObject? in
      return (try? NSXMLDocument(data: content, options: 0)) ?? content
    }
    //enabledLogCategories = LogCategory.detailed
  }
  
  /// Status of the most recent build of the given branch from any project
  /// and build type.
  func buildStatus(branch: String) -> Resource
  {
    return resource("httpAuth/app/rest/builds/running:any,branch:\(branch)")
  }
  
  var vcsRoots: Resource
  { return resource("httpAuth/app/rest/vcs-roots") }
  
  var projects: Resource
  { return resource("httpAuth/app/rest/projects") }
  
  /// A resource for the repo URL of a VCS root. This will be just the URL,
  /// not wrapped in XML.
  func vcsRootURL(vcsRoodID: String) -> Resource
  {
    return resource("httpAuth/app/rest/vcs-roots/id:\(vcsRoodID)/properties/url")
  }
  
  var buildTypes: Resource
  {
    return resource("httpAuth/app/rest/buildTypes")
  }
  
  /// Looks up the VCS root for the given repo URL. You can't use the URL
  /// as a locator, so we have to search through all VCS roots.
  func findVCSRoot(url: String, completion: (Resource?, Error?) -> Void)
  {
    let vcsRoot = TeamCityVCSRoot(url: url, api: self, completion: completion)
  }
}

// Indexing projects:
// - Get VCS roots, build repo URL -> vcs-root id map.
// - Get build types, build buildType <-> vcs-root map.
// - Make a list of build types for each remote
// Look up:
// - /httpAuth/app/rest/builds?locator=running:any,
//    buildType:\(buildType),branch:\(branch)
// - Returns a list of <build href=".."/>, retrieve those

class MetaResource {
  
  typealias Completion = (Resource?, Error?) -> Void
  
  var resource: Resource?
  let api: XTTeamCityAPI
  let completion: Completion
  
  init(api: XTTeamCityAPI, completion: Completion)
  {
    self.api = api
    self.completion = completion
  }
}

class TeamCityVCSRoot: MetaResource {
  
  let vcsURL: String
  
  init(url: String, api: XTTeamCityAPI, completion: Completion)
  {
    self.vcsURL = url
    
    super.init(api: api, completion: completion)

    let vcsRoots = api.vcsRoots
    
    if vcsRoots.latestData != nil {
      parseVCSRoots(vcsRoots)
    }
    else {
      vcsRoots.addObserver(owner: self) {
        (resource: Siesta.Resource, event) in
        switch event {
        case .Error:
          NSLog("Error getting vcs-roots")
        case .NewData:
          self.parseVCSRoots(resource)
        default:
          break
        }
      }
      vcsRoots.loadIfNeeded()
    }
  }
  
  func parseVCSRoots(rootsResource: Resource)
  {
    guard let xml = rootsResource.latestData?.content as? NSXMLDocument,
      let vcsRoots = xml.children?.first?.children
      else {
        NSLog("Couldn't parse vcs-roots")
        // tell the completion handler
        return
    }
    
    for vcsRoot in vcsRoots {
      guard let element = vcsRoot as? NSXMLElement,
        let path = element.attributeForName("href")?.stringValue
        else { continue }
      
      let vcsResource = api.resource(path)
      
      if vcsResource.latestData != nil {
        parseVCSRoot(vcsResource)
      }
      else {
        vcsResource.addObserver(owner: self) {
          (resource: Siesta.Resource, event) in
          switch event {
          case .Error:
            // Failed, but we don't know if it's the one we want
            break
          case .NewData:
            self.parseVCSRoot(resource)
          default:
            break
          }
        }
        vcsResource.loadIfNeeded()
      }
    }
  }
  
  func parseVCSRoot(rootResource: Resource) -> Bool
  {
    guard let xml = rootResource.latestData?.content as? NSXMLDocument,
      let vcsRoot = xml.children?.first as? NSXMLElement,
      let properties = vcsRoot.elementsForName("properties").first?.children
      else { return false }
    
    for property in properties {
      guard let element = property as? NSXMLElement,
        let name = element.attributeForName("name")?.stringValue
        else { continue }
      
      if name == "url" {
        guard let value = element.attributeForName("value")?.stringValue
          else { continue }
        
        if value == vcsURL {
          completion(rootResource, nil)
          return true
        }
      }
    }
    return false
  }
}
