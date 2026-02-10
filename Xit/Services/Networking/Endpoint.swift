import Foundation

/// Represents an HTTP endpoint configuration.
/// Contains all necessary information to construct a URLRequest.
struct Endpoint: Sendable
{
  let baseURL: URL
  let path: String
  let method: HTTPMethod
  let headers: [String: String]
  let queryItems: [URLQueryItem]?
  let body: Data?

  /// HTTP methods supported by the network service
  enum HTTPMethod: String, Sendable
  {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
  }

  /// Creates a new endpoint configuration.
  /// - Parameters:
  ///   - baseURL: The base URL of the API
  ///   - path: The path component to append to the base URL
  ///   - method: The HTTP method (defaults to .get)
  ///   - headers: Additional HTTP headers (defaults to empty)
  ///   - queryItems: URL query parameters (defaults to nil)
  ///   - body: The request body data (defaults to nil)
  init(baseURL: URL,
       path: String,
       method: HTTPMethod = .get,
       headers: [String: String] = [:],
       queryItems: [URLQueryItem]? = nil,
       body: Data? = nil)
  {
    self.baseURL = baseURL
    self.path = path
    self.method = method
    self.headers = headers
    self.queryItems = queryItems
    self.body = body
  }

  /// Constructs the full URL including path and query items.
  /// - Returns: The complete URL or nil if construction fails
  func url() -> URL?
  {
    guard var components = URLComponents(url: baseURL.appendingPathComponent(path),
                                         resolvingAgainstBaseURL: true)
    else { return nil }

    if let queryItems = queryItems, !queryItems.isEmpty {
      components.queryItems = queryItems
    }

    return components.url
  }

  /// Converts the endpoint configuration to a URLRequest.
  /// - Returns: A configured URLRequest
  /// - Throws: NetworkError.invalidURL if the URL cannot be constructed
  func urlRequest() throws -> URLRequest {
    guard let url = url()
    else {
      throw NetworkError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    request.httpBody = body

    for (key, value) in headers {
      request.setValue(value, forHTTPHeaderField: key)
    }

    return request
  }
}
