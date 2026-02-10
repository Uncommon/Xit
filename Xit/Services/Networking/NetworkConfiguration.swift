import Foundation

/// Configuration options for network services.
struct NetworkConfiguration: Sendable
{
  /// Default HTTP headers to include in all requests
  let headers: [String: String]

  /// JSON decoder to use for response parsing
  let decoder: JSONDecoder

  /// Request timeout interval in seconds
  let timeoutInterval: TimeInterval

  /// Creates a network configuration.
  /// - Parameters:
  ///   - headers: Default headers for all requests (defaults to empty)
  ///   - decoder: JSON decoder instance (defaults to new JSONDecoder)
  ///   - timeoutInterval: Request timeout in seconds (defaults to 60)
  init(headers: [String: String] = [:],
       decoder: JSONDecoder = JSONDecoder(),
       timeoutInterval: TimeInterval = 60) {
    self.headers = headers
    self.decoder = decoder
    self.timeoutInterval = timeoutInterval
  }

  /// Default configuration with standard settings
  static let `default` = NetworkConfiguration()
}
