import Foundation
import os

private let authLogger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                                category: "auth")

/// Provides HTTP Basic Authentication by adding Authorization header to requests.
final class BasicAuthProvider: AuthenticationProvider
{
  private let username: String
  private let password: String

  /// Creates a basic auth provider.
  /// - Parameters:
  ///   - username: The username for authentication
  ///   - password: The password for authentication
  init(username: String, password: String)
  {
    self.username = username
    self.password = password
  }

  /// Configures a URLRequest with HTTP Basic Authentication header.
  func configure(request: inout URLRequest) async throws
  {
    let credentials = "\(username):\(password)"

    guard let credentialsData = credentials.data(using: .utf8)
    else {
      authLogger.error("Failed to encode credentials for user: \(self.username)")
      throw AuthenticationError.invalidCredentials
    }

    let base64Credentials = credentialsData.base64EncodedString()
    request.setValue("Basic \(base64Credentials)",
                     forHTTPHeaderField: "Authorization")

    authLogger.debug("Configured basic auth for user: \(self.username)")
  }
}

/// Errors that can occur during authentication.
enum AuthenticationError: Error
{
  /// The credentials could not be encoded
  case invalidCredentials

  /// Authentication failed with the server
  case authenticationFailed
}

extension AuthenticationError: LocalizedError
{
  var errorDescription: String?
  {
    switch self {
      case .invalidCredentials:
        "Invalid credentials format"
      case .authenticationFailed:
        "Authentication failed"
    }
  }
}
