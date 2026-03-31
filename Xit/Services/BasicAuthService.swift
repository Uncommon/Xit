import Foundation
import Combine

extension Notification.Name
{
  static let authenticationStatusChanged = Self("AuthStatusChanged")
}

struct AuthenticationResponse
{
  let data: Data
  let response: URLResponse
}

enum AuthenticationError: LocalizedError
{
  case invalidURL(baseURL: URL, path: String)
  case invalidResponse(URLResponse)
  case unsuccessfulStatus(Int)

  var errorDescription: String?
  {
    switch self {
      case .invalidURL(let baseURL, let path):
        "Could not construct auth URL for \(path) relative to \(baseURL.absoluteString)."
      case .invalidResponse(let response):
        "Unexpected authentication response: \(type(of: response))."
      case .unsuccessfulStatus(let status):
        HTTPURLResponse.localizedString(forStatusCode: status).capitalized
    }
  }
}

/// Abstract service class that handles HTTP basic authentication.
class BasicAuthService: ObservableObject, IdentifiableService
{
  let id = UUID()
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
  private let session: URLSession
  private var authorizationHeader: String?
  private var authenticationTask: URLSessionDataTask?
  private var authenticationToken = UUID()

  init?(account: Account,
        password: String,
        authenticationPath: String,
        session: URLSession = .shared)
  {
    self.account = account
    self.authenticationStatus = .notStarted
    self.authenticationPath = authenticationPath
    self.session = session

    if !updateAuthentication(account.user, password: password) {
      return nil
    }
  }

  required init?(account: Account, password: String)
  {
    assertionFailure(
      "subclasses should call init(account:password:authenticationPath:)")
    return nil
  }

  deinit
  {
    authenticationTask?.cancel()
  }

  /// Re-generates the authentication header with the new credentials.
  func updateAuthentication(_ user: String, password: String) -> Bool
  {
    if let data = "\(user):\(password)"
        .data(using: .utf8)?
        .base64EncodedString(options: []) {
      authorizationHeader = "Basic \(data)"
      return true
    }
    else {
      serviceLogger.debug("""
          Couldn't construct auth header for \
          \(user) @ \(self.account.location.absoluteString)
          """)
      authorizationHeader = nil
      return false
    }
  }

  /// Checks that the user and password are accepted by the server.
  func attemptAuthentication(_ path: String? = nil)
  {
    let resolvedPath = path ?? authenticationPath
    guard let url = authenticationURL(for: resolvedPath) else {
      authenticationStatus = .failed(
        AuthenticationError.invalidURL(baseURL: account.location,
                                       path: resolvedPath))
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    if let authorizationHeader {
      request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
    }

    let token = UUID()
    let task = session.dataTask(with: request) {
      [weak self] data, response, error in
      self?.handleAuthenticationResult(token: token,
                                       data: data,
                                       response: response,
                                       error: error)
    }

    objc_sync_enter(self)
    let previousTask = authenticationTask
    authenticationToken = token
    authenticationTask = task
    objc_sync_exit(self)

    previousTask?.cancel()
    authenticationStatus = .inProgress
    task.resume()
  }

  // For subclasses to override when more data needs to be downloaded.
  func didAuthenticate(response: AuthenticationResponse)
  {
  }

  private func authenticationURL(for path: String) -> URL?
  {
    guard !path.isEmpty
    else { return account.location }
    
    return URL(string: path, relativeTo: account.location)?.absoluteURL
  }

  private func handleAuthenticationResult(token: UUID,
                                          data: Data?,
                                          response: URLResponse?,
                                          error: Error?)
  {
    let isCurrentTask: Bool = {
      objc_sync_enter(self)
      defer { objc_sync_exit(self) }
      
      guard authenticationToken == token
      else { return false }
      
      authenticationTask = nil
      return true
    }()
    guard isCurrentTask
    else { return }

    if let urlError = error as? URLError,
       urlError.code == .cancelled {
      authenticationStatus = .notStarted
      return
    }
    else if let error {
      authenticationStatus = .failed(error)
      return
    }

    guard let response = response as? HTTPURLResponse else {
      authenticationStatus = .failed(
          response.map(AuthenticationError.invalidResponse) ?? nil)
      return
    }

    guard (200..<300).contains(response.statusCode) else {
      authenticationStatus = .failed(
          AuthenticationError.unsuccessfulStatus(response.statusCode))
      return
    }

    authenticationStatus = .done
    didAuthenticate(response: .init(data: data ?? Data(), response: response))
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

    account = newAccount
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
      _ = try? await Task.sleep(nanoseconds: 1_000_000_000)
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
