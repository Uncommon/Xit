import Foundation

/// Protocol for authentication providers that can configure URLRequests with
/// auth credentials.
protocol AuthenticationProvider: Sendable {
  /// Configures a URLRequest with authentication credentials.
  /// - Parameter request: The URLRequest to configure (passed as inout)
  /// - Throws: Error if authentication configuration fails
  func configure(request: inout URLRequest) async throws
}
