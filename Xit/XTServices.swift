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


public func XMLResponseTransformer(
    transformErrors: Bool = true) -> Siesta.ResponseTransformer
{
  return Siesta.ResponseContentTransformer(transformErrors: transformErrors) {
    (content: NSData, entity: Siesta.Entity) throws -> NSXMLDocument in
    return try NSXMLDocument(data: content, options: 0)
  }
}

