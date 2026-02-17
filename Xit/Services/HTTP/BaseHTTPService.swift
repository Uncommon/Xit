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
    self.networkService = networkService ??
        URLSessionNetworkService(
          session: .init(configuration: .default),
          configuration: .init(headers: [:]),
          authProvider: self.authProvider
        )
  }
  
  /// Re-generates the authentication header with the new credentials.
  /// Returns 'true' on success, 'false' if credentials are invalid.
  func updateAuthentication(_ user: String, password: String) -> Bool
  {
    guard let _ = "\(user):\(password)".data(using: .utf8)?.base64EncodedString()
    else {
      return false
    }
    
    // Replace the provider used by this service instance
    let newProvider = BasicAuthProvider(username: user, password: password)
    authProvider = newProvider
    
    // Propagate to the concrete network service when possible
    if let urlService = networkService as? URLSessionNetworkService {
      urlService.authProvider = newProvider
    }
    
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
      let data: Data = try await networkService.request(endpoint)
      
      self.authenticationStatus = .done
      await didAuthenticate(data: data)
    }
    catch {
      self.authenticationStatus = .failed(error)
    }
  }
  
  /// Hook for subclasses to process successful authentication response
  func didAuthenticate(data: Data) async {}
  
  /// Updates the account and attempts re-authentication
  func accountUpdated(oldAccount: Account, newAccount: Account)
  {
    guard oldAccount == account
    else { return }
    
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
