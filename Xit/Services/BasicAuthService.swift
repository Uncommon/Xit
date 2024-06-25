import Foundation
import Combine
import Siesta

extension Notification.Name
{
  static let authenticationStatusChanged = Self("AuthStatusChanged")
}

protocol BasicAuthenticatorDelegate: AnyObject
{
  func didAuthenticate(responseResource: Resource)
}

protocol Authentication
{
  var authenticationStatusPublisher: any Publisher<Services.Status, Never> { get }
}

class BasicAuthenticator: ObservableObject
{
  let account: Account
  @Published var authenticationStatus: Services.Status
  var password: String
  private let authenticationPath: String
  weak var delegate: BasicAuthenticatorDelegate?

  init?(account: Account, password: String, authenticationPath: String)
  {
    self.account = account
    self.password = password
    self.authenticationStatus = .notStarted
    self.authenticationPath = authenticationPath
  }

  func configure(service: Service)
  {
    service.configure {
      (builder) in
      if let data = "\(self.account.user):\(self.password)"
        .data(using: String.Encoding.utf8)?
        .base64EncodedString(options: []) {
        builder.headers["Authorization"] = "Basic \(data)"
      }
      else {
        serviceLogger.debug("""
        Couldn't construct auth header for \
        \(self.account.user) @ \(service.baseURL?.absoluteString ?? "?")
        """)
      }
    }
  }

  /// Checks that the user and password are accepted by the server.
  func attemptAuthentication(service: Service, path: String? = nil)
  {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }

    authenticationStatus = .inProgress

    let path = path ?? authenticationPath
    let authResource = service.resource(path)

    for request in authResource.allRequests {
      request.cancel()
    }
    authResource.addObserver(owner: self) {
      [self] (resource, event) in
      switch event {

        case .newData, .notModified:
          authenticationStatus = .done
          delegate?.didAuthenticate(responseResource: resource)

        case .error:
          guard let error = resource.latestError
          else {
            serviceLogger.debug("Error event with no error")
            authenticationStatus = .failed(nil)
            return
          }

          authenticationStatus =
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
}

extension BasicAuthenticator: Authentication
{
  var authenticationStatusPublisher: any Publisher<Services.Status, Never>
  {
    $authenticationStatus
  }
}

/// Abstract service class that handles HTTP basic authentication.
class BasicAuthService: IdentifiableService, ObservableObject
{
  var account: Account
  var authenticationStatus: Services.Status
  {
    willSet
    {
      Thread.syncOnMain {
        objectWillChange.send()
      }
    }
    didSet
    {
      NotificationCenter.default.post(name: .authenticationStatusChanged,
                                      object: self)
    }
  }
  private let authenticationPath: String
  
  init?(account: Account, password: String, authenticationPath: String)
  {
    self.account = account
    self.authenticationStatus = .notStarted
    self.authenticationPath = authenticationPath
    
    // Exclude the JSON transformer because we'll use JSONDecoder instead
    super.init(baseURL: account.location, standardTransformers: [.text, .image])
    
    if !updateAuthentication(account.user, password: password) {
      return nil
    }
    configure {
      (builder) in
      builder.decorateRequests {
        (resource, request) in
        request.onFailure {
          (error) in
          serviceLogger.debug(
              "Request error: \(error.userMessage) \(resource.url)")
        }
      }
    }
  }

  required init?(account: Account, password: String)
  {
    assertionFailure(
      "subclasses should call init(account:password:authenticationPath:)")
    return nil
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
      }
      return true
    }
    else {
      serviceLogger.debug("""
          Couldn't construct auth header for \
          \(user) @ \(self.baseURL?.absoluteString ?? "?")
          """)
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
            serviceLogger.debug("Error event with no error")
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

extension BasicAuthService: AccountService
{
  func accountUpdated(oldAccount: Account, newAccount: Account)
  {
    guard oldAccount == account
    else { return }
    guard let password = KeychainStorage.shared.find(account: newAccount)
    else {
      authenticationStatus = .unknown
      return
    }
    
    _ = updateAuthentication(newAccount.user, password: password)
    attemptAuthentication()
  }
}

class MockAuthService: BasicAuthService
{
  init(account: Account)
  {
    super.init(account: account, password: "", authenticationPath: "")!
  }

  required init?(account: Account, password: String)
  { fatalError("init(account:password:) has not been implemented") }

  override func attemptAuthentication(_ path: String? = nil)
  {
    authenticationStatus = .inProgress
    Task {
      _ = try? await Task.sleep(nanoseconds: 1000000000)
      authenticationStatus = .done
    }
  }

  static func maker(_ account: Account) -> MockAuthService
  {
    let service = MockAuthService(account: account)
    service.attemptAuthentication()
    return service
  }
}
