import Cocoa
import Siesta

extension Siesta.Resource
{
  /// Either executes the closure with the resource's data, or schedules it
  /// to run later when the data is available.
  func useData(owner: AnyObject, closure: @escaping (Siesta.Entity<Any>) -> ())
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
class XTServices: NSObject
{
  /// Status of server operations such as authentication.
  enum Status
  {
    case unknown
    case notStarted
    case inProgress
    case done
    case failed(Error?)
  }
  
  static let services = XTServices()
  
  private var teamCityServices: [String: XTTeamCityAPI] = [:]
  
  /// Creates an API object for each account so they can start with
  /// authorization and other state info.
  func initializeServices()
  {
    for account in XTAccountsManager.manager.accounts(ofType: .teamCity) {
      _ = teamCityAPI(account)
    }
  }
  
  private static func accountKey(_ account: Account) -> String
  {
    if let host = account.location.host {
      return "\(account.user)@\(host)"
    }
    else {
      return account.user
    }
  }
  
  /// Returns the TeamCity service object for the given account, or nil if
  /// the password cannot be found.
  func teamCityAPI(_ account: Account) -> XTTeamCityAPI?
  {
    let key = XTServices.accountKey(account)
  
    if let api = teamCityServices[key] {
      return api
    }
    else {
      guard let password = XTKeychain.findPassword(url: account.location,
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


extension XTServices.Status: Equatable {
}

// This doesn't come for free because of the associated value on .failed
func ==(a: XTServices.Status, b: XTServices.Status) -> Bool
{
  switch (a, b) {
    case (.unknown, .unknown),
         (.notStarted, .notStarted),
         (.inProgress, .inProgress),
         (.done, .done):
      return true
    case (.failed(_), .failed(_)):
      return true
    default:
      return false
  }
}


/// Protocol to be implemented by all concrete API classes.
protocol XTServiceAPI {
  var type: AccountType { get }
  
}


/// Abstract service class that handles HTTP basic authentication.
class XTBasicAuthService : Service
{
  static let AuthenticationStatusChangedNotification = "AuthStatusChanged"
  
  private(set) var authenticationStatus: XTServices.Status
  {
    didSet
    {
      NotificationCenter.default.post(
          name: Notification.Name(rawValue: XTBasicAuthService.AuthenticationStatusChangedNotification),
          object: self)
    }
  }
  private let authenticationPath: String
  
  init?(user: String, password: String, baseURL: String?,
        authenticationPath: String) {
    self.authenticationStatus = .notStarted
    self.authenticationPath = authenticationPath
    
    super.init(baseURL: baseURL)
  
    if !updateAuthentication(user, password: password) {
      return nil
    }
  }
  
  /// Re-generates the authentication header with the new credentials.
  func updateAuthentication(_ user: String, password: String) -> Bool
  {
    if let data = "\(user):\(password)"
      .data(using: String.Encoding.utf8)?
      .base64EncodedString(options: []) {
      configure { (builder) in
        builder.headers["Authorization"] = "Basic \(data)"
        builder.decorateRequests { (resource, request) in
          request.onFailure { (error) in
            NSLog("Request error: \(error.userMessage) \(resource.url)")
          }
        }
      }
      return true
    }
    else {
      NSLog("Couldn't construct auth header for " +
            "\(user) @ \(String(describing: baseURL))")
      return false
    }
  }
  
  /// Checks that the user and password are accepted by the server.
  func attemptAuthentication(_ path: String? = nil)
  {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    
    authenticationStatus = .inProgress
    
    let path = path ?? authenticationPath
    let authResource = resource(path)
    
    for request in authResource.allRequests {
      request.cancel()
    }
    authResource.addObserver(owner: self) {
      (resource, event) in
      switch event {

        case .newData, .notModified:
          self.authenticationStatus = .done
          self.didAuthenticate()

        case .error:
          guard let error = resource.latestError
          else {
            NSLog("Error event with no error")
            return
          }
          
          if !(error.cause is Siesta.RequestError.Cause.RequestCancelled) {
            self.authenticationStatus = .failed(error)
          }

        default:
          break
      }
    }
    // Use a custom request to skip the XML transformer
    _ = authResource.load(using: authResource.request(.get))
  }
  
  // For subclasses to override when more data needs to be downloaded.
  func didAuthenticate()
  {
  }
}


public func XMLResponseTransformer(
    _ transformErrors: Bool = true) -> Siesta.ResponseTransformer
{
  return Siesta.ResponseContentTransformer<Data, XMLDocument>(
      transformErrors: transformErrors) {
    (entity: Siesta.Entity<Data>) throws -> XMLDocument? in
    return try XMLDocument(data: entity.content, options: 0)
  }
}
