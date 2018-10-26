import Foundation
import Siesta

/// Abstract service class that handles HTTP basic authentication.
class BasicAuthService: Siesta.Service
{
  static let AuthenticationStatusChangedNotification = "AuthStatusChanged"
  
  var authenticationStatus: Services.Status
  {
    didSet
    {
      NotificationCenter.default.post(
        name: Notification.Name(rawValue:
          BasicAuthService.AuthenticationStatusChangedNotification),
        object: self)
    }
  }
  private let authenticationPath: String
  
  init?(user: String, password: String,
        baseURL: String?,
        authenticationPath: String)
  {
    self.authenticationStatus = .notStarted
    self.authenticationPath = authenticationPath
    
    // Exclude the JSON transformer because we'll use JSONDecoder instead
    super.init(baseURL: baseURL, standardTransformers: [.text, .image])
    
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
      configure {
        (builder) in
        builder.headers["Authorization"] = "Basic \(data)"
        builder.decorateRequests {
          (resource, request) in
          request.onFailure {
            (error) in
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
        self.didAuthenticate(responseResource: resource)
        
      case .error:
        guard let error = resource.latestError
          else {
            NSLog("Error event with no error")
            self.authenticationStatus = .failed(nil)
            return
        }
        
        self.authenticationStatus =
          (error.cause is Siesta.RequestError.Cause.RequestCancelled)
          ? .notStarted
          : .failed(error)
        
      default:
        break
      }
    }
    // Use a custom request to skip the XML transformer
    _ = authResource.load(using: authResource.request(.get))
  }
  
  // For subclasses to override when more data needs to be downloaded.
  func didAuthenticate(responseResource: Resource)
  {
  }
}
