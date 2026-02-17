import Foundation

/// Core protocol for network service implementations.
/// Provides methods for making HTTP requests with type-safe responses.
protocol NetworkService
{
  /// Makes a network request and decodes the response to the specified type.
  /// - Parameter endpoint: The endpoint configuration for the request
  /// - Returns: The decoded response of type T
  /// - Throws: NetworkError if the request fails or decoding fails
  func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
  
  /// Makes a network request and returns raw data.
  /// - Parameter endpoint: The endpoint configuration for the request
  /// - Returns: The raw response data
  /// - Throws: NetworkError if the request fails
  func request(_ endpoint: Endpoint) async throws -> Data
}
