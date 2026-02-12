import Testing
@testable import Xit

/// Tests for the core networking layer components.
@Suite
struct NetworkServiceTests
{
  // MARK: - Endpoint Tests

  @Test
  func endpointURLConstruction()
  {
    let baseURL = URL(string: "https://api.example.com")!
    let endpoint = Endpoint(baseURL: baseURL, path: "/users/123", method: .get)

    let url = endpoint.url()
    #expect(url?.absoluteString == "https://api.example.com/users/123")
  }

  @Test
  func endpointWithQueryItems()
  {
    let baseURL = URL(string: "https://api.example.com")!
    let endpoint = Endpoint(baseURL: baseURL,path: "/search",
                            queryItems: [
                              URLQueryItem(name: "q", value: "swift"),
                              URLQueryItem(name: "limit", value: "10")
                            ])

    let url = endpoint.url()
    #expect(url?.absoluteString.contains("q=swift") ?? false)
    #expect(url?.absoluteString.contains("limit=10") ?? false)
  }

  @Test
  func endpointURLRequest() throws
  {
    let baseURL = URL(string: "https://api.example.com")!
    let endpoint = Endpoint(baseURL: baseURL, path: "/data", method: .post,
                            headers: ["X-Custom": "Value"],
                            body: "test".data(using: .utf8))

    let request = try endpoint.urlRequest()
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "X-Custom") == "Value")
    #expect(request.httpBody == "test".data(using: .utf8))
  }

  // MARK: - URLSessionNetworkService Tests

  @Test
  func successfulRequest() async throws
  {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]

    let sessionID = UUID().uuidString
    var headers = config.httpAdditionalHeaders as? [String: String] ?? [:]
    headers["X-MockURLProtocol-SessionID"] = sessionID
    config.httpAdditionalHeaders = headers

    let mockSession = URLSession(configuration: config)

    let service = URLSessionNetworkService(session: mockSession)
    let endpoint = Endpoint(baseURL: URL(string: "https://api.example.com")!,
                            path: "/data")

    let responseData = "test response".data(using: .utf8)!

    Task {
      await MockURLProtocol.handlerStore.setHandler(for: sessionID) { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!
        return (response, responseData)
      }
    }

    let data = try await service.request(endpoint)
    #expect(data == responseData)

    await MockURLProtocol.handlerStore.removeHandler(for: sessionID)
  }

  @Test
  func decodableRequest() async throws
  {
    struct TestResponse: Codable
    {
      let message: String
      let count: Int
    }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]

    let sessionID = UUID().uuidString
    var headers = config.httpAdditionalHeaders as? [String: String] ?? [:]
    headers["X-MockURLProtocol-SessionID"] = sessionID
    config.httpAdditionalHeaders = headers

    let mockSession = URLSession(configuration: config)

    let service = URLSessionNetworkService(session: mockSession)
    let endpoint = Endpoint(baseURL: URL(string: "https://api.example.com")!,
                            path: "/data")

    let testObject = TestResponse(message: "Hello", count: 42)
    let responseData = try JSONEncoder().encode(testObject)

    await MockURLProtocol.handlerStore.setHandler(for: sessionID) { request in
      let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                     httpVersion: nil, headerFields: nil)!
      return (response, responseData)
    }

    let result: TestResponse = try await service.request(endpoint)
    #expect(result.message == "Hello")
    #expect(result.count == 42)

    await MockURLProtocol.handlerStore.removeHandler(for: sessionID)
  }

  @Test
  func unauthorizedError() async throws
  {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]

    let sessionID = UUID().uuidString
    var headers = config.httpAdditionalHeaders as? [String: String] ?? [:]
    headers["X-MockURLProtocol-SessionID"] = sessionID
    config.httpAdditionalHeaders = headers

    let mockSession = URLSession(configuration: config)

    let service = URLSessionNetworkService(session: mockSession)
    let endpoint = Endpoint(baseURL: URL(string: "https://api.example.com")!,
                            path: "/data")

    await MockURLProtocol.handlerStore.setHandler(for: sessionID) { request in
      let response = HTTPURLResponse(url: request.url!, statusCode: 401,
                                     httpVersion: nil, headerFields: nil)!
      return (response, Data())
    }

    do {
      _ = try await service.request(endpoint)
      Issue.record("Expected unauthorized error")
    }
    catch let error as NetworkError {
      if case .unauthorized = error {
        // Success
      }
      else {
        Issue.record("Expected unauthorized error, got \(error)")
      }
    }

    await MockURLProtocol.handlerStore.removeHandler(for: sessionID)
  }

  @Test
  func serverError() async throws
  {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]

    let sessionID = UUID().uuidString
    var headers = config.httpAdditionalHeaders as? [String: String] ?? [:]
    headers["X-MockURLProtocol-SessionID"] = sessionID
    config.httpAdditionalHeaders = headers

    let mockSession = URLSession(configuration: config)

    let service = URLSessionNetworkService(session: mockSession)
    let endpoint = Endpoint(baseURL: URL(string: "https://api.example.com")!,
                            path: "/data")

    await MockURLProtocol.handlerStore.setHandler(for: sessionID) { request in
      let response = HTTPURLResponse(url: request.url!, statusCode: 500,
                                     httpVersion: nil, headerFields: nil)!
      return (response, Data())
    }

    do {
      _ = try await service.request(endpoint)
      Issue.record("Expected server error")
    }
    catch let error as NetworkError {
      if case .serverError(let code) = error {
        #expect(code == 500)
      }
      else {
        Issue.record("Expected server error, got \(error)")
      }
    }

    await MockURLProtocol.handlerStore.removeHandler(for: sessionID)
  }

  @Test
  func decodingError() async throws
  {
    struct TestResponse: Codable
    {
      let message: String
    }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]

    let sessionID = UUID().uuidString
    var headers = config.httpAdditionalHeaders as? [String: String] ?? [:]
    headers["X-MockURLProtocol-SessionID"] = sessionID
    config.httpAdditionalHeaders = headers

    let mockSession = URLSession(configuration: config)

    let service = URLSessionNetworkService(session: mockSession)
    let endpoint = Endpoint(baseURL: URL(string: "https://api.example.com")!,
                            path: "/data")

    let invalidJSON = "invalid json".data(using: .utf8)!

    await MockURLProtocol.handlerStore.setHandler(for: sessionID) { request in
      let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                     httpVersion: nil, headerFields: nil)!
      return (response, invalidJSON)
    }

    do {
      let _: TestResponse = try await service.request(endpoint)
      Issue.record("Expected decoding error")
    }
    catch let error as NetworkError {
      if case .decodingError = error {
        // Success
      }
      else {
        Issue.record("Expected decoding error, got \(error)")
      }
    }

    await MockURLProtocol.handlerStore.removeHandler(for: sessionID)
  }

  @Test
  func configurationHeaders() async throws
  {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]

    let sessionID = UUID().uuidString
    var headers = config.httpAdditionalHeaders as? [String: String] ?? [:]
    headers["X-MockURLProtocol-SessionID"] = sessionID
    config.httpAdditionalHeaders = headers

    let mockSession = URLSession(configuration: config)

    let netConfig = NetworkConfiguration(headers: ["X-API-Key": "secret123"])
    let service = URLSessionNetworkService(session: mockSession,
                                           configuration: netConfig)
    let endpoint = Endpoint(baseURL: URL(string: "https://api.example.com")!,
                            path: "/data")

    var capturedRequest: URLRequest?
    await MockURLProtocol.handlerStore.setHandler(for: sessionID) { request in
      capturedRequest = request
      let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                     httpVersion: nil, headerFields: nil)!
      return (response, Data())
    }

    _ = try await service.request(endpoint)

    #expect(
      capturedRequest?.value(forHTTPHeaderField: "X-API-Key") == "secret123"
    )

    await MockURLProtocol.handlerStore.removeHandler(for: sessionID)
  }
}

// MARK: - Mock URLProtocol

/// Thread-safe storage for mock request handlers, isolated per session identifier.
actor MockRequestHandlerStore
{
  private var handlers: [String: (URLRequest) throws -> (HTTPURLResponse, Data)] = [:]

  func setHandler(for identifier: String,
                  handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data))
  {
    handlers[identifier] = handler
  }

  func getHandler(for identifier: String) -> ((URLRequest) throws -> (HTTPURLResponse, Data))?
  {
    handlers[identifier]
  }

  func removeHandler(for identifier: String)
  {
    handlers.removeValue(forKey: identifier)
  }
}

/// Mock URLProtocol for testing URLSession-based networking.
/// Thread-safe and supports parallel test execution by using unique session identifiers
/// stored in the URLSessionConfiguration.
class MockURLProtocol: URLProtocol
{
  static let handlerStore = MockRequestHandlerStore()
  private static let sessionIDHeader = "X-MockURLProtocol-SessionID"

  override class func canInit(with request: URLRequest) -> Bool
  {
    // Only intercept requests that have our session ID header
    request.value(forHTTPHeaderField: sessionIDHeader) != nil
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest
  {
    request
  }

  override func startLoading()
  {
    guard let sessionID = request.value(forHTTPHeaderField: Self.sessionIDHeader)
    else {
      client?.urlProtocol(self, didFailWithError:
                            URLError(.unknown, userInfo: [NSLocalizedDescriptionKey: "No session ID in request"]))
      return
    }

    Task {
      guard let client = self.client
      else { return }
      guard let handler = await MockURLProtocol.handlerStore.getHandler(for: sessionID)
      else {
        client.urlProtocol(self, didFailWithError:
                                  URLError(.unknown, userInfo: [NSLocalizedDescriptionKey: "Handler not set for session \(sessionID)"]))
        return
      }

      do {
        let (response, data) = try handler(self.request)
        client.urlProtocol(self, didReceive: response,
                                 cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: data)
        client.urlProtocolDidFinishLoading(self)
      }
      catch {
        client.urlProtocol(self, didFailWithError: error)
      }
    }
  }

  override func stopLoading()
  {
  }
}
