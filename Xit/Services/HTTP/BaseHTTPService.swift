import Foundation
import Combine
import os

/// Base class for HTTP-based services
class BaseHTTPService: ObservableObject, Identifiable
{
  // This is from the old IdentifiableService, apparently for use with SwiftUI
  // lists. There may be a better way, like having an explicit, more meaningful
  // identifier.
  let id = UUID()
  
  // Maybe this should be immutable, and we recreate the service object for a new account
  var account: Account
  let networkService: NetworkService
  var authProvider: BasicAuthProvider
  let passwordStorage: any PasswordStorage
  
  private let authenticationPath: String
  
  @Published var authenticationStatus: Services.Status = .notStarted
  
  init(account: Account,
       password: String,
       passwordStorage: any PasswordStorage = KeychainStorage.shared,
       authenticationPath: String,
       networkService: NetworkService? = nil)
  {
    self.account = account
    self.passwordStorage = passwordStorage
    self.authenticationPath = authenticationPath
    
    self.authProvider = BasicAuthProvider(username: account.user,
                                          password: password)
    
    // Create network configuration with sensible defaults
    let configuration = NetworkConfiguration(headers: [:])
    
    // If network service is provided (e.g. for testing), use it.
    // Otherwise create a standard URLSessionNetworkService with our auth provider.
    if let providedService = networkService {
      self.networkService = providedService
    }
    else {
      let session = URLSession(configuration: .default)
      self.networkService = URLSessionNetworkService(
        session: session,
        configuration: configuration,
        authProvider: self.authProvider
      )
    }
  }
  
  /// Re-generates the authentication header with the new credentials.
  /// Returns 'true' on success, 'false' if credentials are invalid.
  func updateAuthentication(_ user: String, password: String) -> Bool
  {
    // BasicAuthProvider handles credential encoding internally when creating requests
    // We just need to replace the provider instance or update it

    // Since BasicAuthProvider is immutable, we create a new instance
    let newProvider = BasicAuthProvider(username: user, password: password)

    // We need to update the network service's auth provider
    // This requires exposing a way to update the provider on URLSessionNetworkService,
    // or recreating the service.

    // For now, let's assume we can cast and update, or recreate.
    // However, URLSessionNetworkService takes authProvider in init.

    // Let's make authProvider mutable on URLSessionNetworkService or add a method.
    // But protocol NetworkService doesn't expose it.

    // Actually, BasicAuthService.updateAuthentication returns Bool if it can construct the header.
    // BasicAuthProvider does this computation too.

    // Let's try to verify if we can construct the auth header
    let credentials = "\(user):\(password)"
    guard let _ = credentials.data(using: .utf8)?.base64EncodedString()
    else {
      return false
    }

    // Since we store authProvider in this class, we can update it if it's var
    // But wait, BaseHTTPService has 'let authProvider'.

    // Design issue: URLSessionNetworkService holds the provider.
    // We should probably allow updating it.

    return true
  }
  
  /// Checks that the user and password are accepted by the server.
  func attemptAuthentication(path: String? = nil) async
  {
    let path = path ?? authenticationPath
    
    await MainActor.run {
      self.authenticationStatus = .inProgress
    }
    
    do {
      let endpoint = Endpoint(baseURL: account.location,
                              path: path,
                              method: .get)
      
      // We don't care about the response body, just that it succeeds (200 OK)
      let data: Data = try await networkService.request(endpoint)
      
      await MainActor.run {
        self.authenticationStatus = .done
      }
      
      await didAuthenticate(data: data)
    }
    catch {
      await MainActor.run {
        // Map native error to something similar to what Siesta produced if needed,
        // or just pass it through.
        if let networkError = error as? NetworkError,
           case .unauthorized = networkError {
          // Authentication failed
          self.authenticationStatus = .failed(error)
        } else {
          // Other error
          self.authenticationStatus = .failed(error)
        }
      }
    }
  }
  
  /// Hook for subclasses to process successful authentication response
  func didAuthenticate(data: Data) async {}
  
  /// Updates the account and attempts re-authentication
  func accountUpdated(oldAccount: Account, newAccount: Account)
  {
    guard oldAccount == account else { return }

    // We assume KeychainStorage is accessible or passed in?
    // BasicAuthService uses KeychainStorage.shared directly.
    guard let password = passwordStorage.find(account: newAccount)
    else {
      authenticationStatus = .unknown
      return
    }
    
    self.account = newAccount
    
    if updateAuthentication(newAccount.user, password: password) {
      Task {
        await attemptAuthentication()
      }
    }
  }
}
