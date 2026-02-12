import Foundation
import os

private let networkLogger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                                   category: "network")

/// URLSession-based implementation of NetworkService.
/// Provides async/await networking using native URLSession APIs.
final class URLSessionNetworkService: NetworkService
{
  private let session: URLSession
  private let decoder: JSONDecoder
  private let configuration: NetworkConfiguration

  /// Authentication provider for signing requests
  let authProvider: AuthenticationProvider?

  /// Creates a new URLSession-based network service.
  /// - Parameters:
  ///   - session: The URLSession to use (defaults to .shared)
  ///   - configuration: Network configuration options
  ///   - authProvider: Authentication provider to sign requests (optional)
  init(session: URLSession = .shared,
       configuration: NetworkConfiguration = .default,
       authProvider: AuthenticationProvider? = nil)
  {
    self.session = session
    self.configuration = configuration
    self.authProvider = authProvider
    self.decoder = configuration.decoder
  }

  /// Makes a network request and decodes the response to the specified type.
  func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
  {
    let data = try await request(endpoint)

    do {
      return try decoder.decode(T.self, from: data)
    }
    catch {
      networkLogger.error("Decoding error: \(error.localizedDescription)")
      throw NetworkError.decodingError(error)
    }
  }

  /// Makes a network request and returns raw data.
  func request(_ endpoint: Endpoint) async throws -> Data
  {
    var urlRequest = try endpoint.urlRequest()

    // Apply default headers from configuration
    for (key, value) in configuration.headers {
      if urlRequest.value(forHTTPHeaderField: key) == nil {
        urlRequest.setValue(value, forHTTPHeaderField: key)
      }
    }

    // Apply authentication
    if let provider = authProvider {
      try await provider.configure(request: &urlRequest)
    }

    urlRequest.timeoutInterval = configuration.timeoutInterval

    networkLogger.debug("Request: \(urlRequest.httpMethod ?? "GET") \(urlRequest.url?.absoluteString ?? "unknown")")

    let (data, response): (Data, URLResponse)

    do {
      (data, response) = try await session.data(for: urlRequest)
    }
    catch let error as URLError where error.code == .cancelled {
      throw NetworkError.cancelled
    }
    catch {
      networkLogger.error("Request failed: \(error.localizedDescription)")
      throw NetworkError.requestFailed(error)
    }

    guard let httpResponse = response as? HTTPURLResponse
    else {
      networkLogger.error("Invalid response type")
      throw NetworkError.invalidResponse
    }

    networkLogger.debug("Response: \(httpResponse.statusCode) for \(urlRequest.url?.absoluteString ?? "unknown")")

    switch httpResponse.statusCode {
      case 200...299:
        return data
      case 401:
        throw NetworkError.unauthorized
      default:
        throw NetworkError.serverError(httpResponse.statusCode)
    }
  }
}
