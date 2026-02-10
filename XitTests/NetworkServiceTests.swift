import Testing
@testable import Xit

/// Tests for the core networking layer components.
@Suite("Network Service Tests")
struct NetworkServiceTests
{
  // MARK: - Endpoint Tests
  
  @Test("Endpoint URL construction")
  func endpointURLConstruction()
  {
    let baseURL = URL(string: "https://api.example.com")!
    let endpoint = Endpoint(baseURL: baseURL, path: "/users/123", method: .get)
    
    let url = endpoint.url()
    #expect(url?.absoluteString == "https://api.example.com/users/123")
  }
  
  @Test("Endpoint with query items")
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
  
  @Test("Endpoint URLRequest creation")
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
  
  @Test("Successful network request")
  func successfulRequest() async throws
  {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let mockSession = URLSession(configuration: config)
    
    let service = URLSessionNetworkService(session: mockSession)
    let endpoint = Endpoint(baseURL: URL(string: "https://api.example.com")!,
                            path: "/data")
    
    let responseData = "test response".data(using: .utf8)!
    MockURLProtocol.requestHandler = { request in
      let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                     httpVersion: nil, headerFields: nil)!
      return (response, responseData)
    }
    
    let data = try await service.request(endpoint)
    #expect(data == responseData)
    
    MockURLProtocol.reset()
  }
  
  @Test("Decodable request")
  func decodableRequest() async throws
  {
    struct TestResponse: Codable
    {
      let message: String
      let count: Int
    }
    
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let mockSession = URLSession(configuration: config)
    
    let service = URLSessionNetworkService(session: mockSession)
    let endpoint = Endpoint(baseURL: URL(string: "https://api.example.com")!,
                            path: "/data")
    
    let testObject = TestResponse(message: "Hello", count: 42)
    let responseData = try JSONEncoder().encode(testObject)
    
    MockURLProtocol.requestHandler = { request in
      let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                     httpVersion: nil, headerFields: nil)!
      return (response, responseData)
    }
    
    let result: TestResponse = try await service.request(endpoint)
    #expect(result.message == "Hello")
    #expect(result.count == 42)
    
    MockURLProtocol.reset()
  }
  
  @Test("Unauthorized error handling")
  func unauthorizedError() async throws
  {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let mockSession = URLSession(configuration: config)
    
    let service = URLSessionNetworkService(session: mockSession)
    let endpoint = Endpoint(baseURL: URL(string: "https://api.example.com")!,
                            path: "/data")
    
    MockURLProtocol.requestHandler = { request in
      let response = HTTPURLResponse(url: request.url!, statusCode: 401,
                                     httpVersion: nil, headerFields: nil)!
      return (response, Data())
    }
    
    await #expect(throws: NetworkError.self) {
      try await service.request(endpoint)
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
    
    MockURLProtocol.reset()
  }
  
  @Test("Server error handling")
  func serverError() async throws
  {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let mockSession = URLSession(configuration: config)
    
    let service = URLSessionNetworkService(session: mockSession)
    let endpoint = Endpoint(baseURL: URL(string: "https://api.example.com")!,
                            path: "/data")
    
    MockURLProtocol.requestHandler = { request in
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
    
    MockURLProtocol.reset()
  }
  
  @Test("Decoding error handling")
  func decodingError() async throws
  {
    struct TestResponse: Codable
    {
      let message: String
    }
    
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let mockSession = URLSession(configuration: config)
    
    let service = URLSessionNetworkService(session: mockSession)
    let endpoint = Endpoint(baseURL: URL(string: "https://api.example.com")!,
                            path: "/data")
    
    let invalidJSON = "invalid json".data(using: .utf8)!
    
    MockURLProtocol.requestHandler = { request in
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
    
    MockURLProtocol.reset()
  }
  
  @Test("Configuration headers")
  func configurationHeaders() async throws
  {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let mockSession = URLSession(configuration: config)
    
    let netConfig = NetworkConfiguration(headers: ["X-API-Key": "secret123"])
    let service = URLSessionNetworkService(session: mockSession,
                                           configuration: netConfig)
    let endpoint = Endpoint(baseURL: URL(string: "https://api.example.com")!,
                            path: "/data")
    
    var capturedRequest: URLRequest?
    MockURLProtocol.requestHandler = { request in
      capturedRequest = request
      let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                     httpVersion: nil, headerFields: nil)!
      return (response, Data())
    }
    
    _ = try await service.request(endpoint)
    
    #expect(
      capturedRequest?.value(forHTTPHeaderField: "X-API-Key") == "secret123"
    )
    
    MockURLProtocol.reset()
  }
}

// MARK: - Mock URLProtocol

/// Mock URLProtocol for testing URLSession-based networking.
class MockURLProtocol: URLProtocol
{
  static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
  
  override class func canInit(with request: URLRequest) -> Bool
  {
    true
  }
  
  override class func canonicalRequest(for request: URLRequest) -> URLRequest
  {
    request
  }
  
  override func startLoading()
  {
    guard let handler = MockURLProtocol.requestHandler
    else {
      fatalError("Handler is not set")
    }
    
    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    }
    catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }
  
  override func stopLoading()
  {
  }
  
  static func reset()
  {
    requestHandler = nil
  }
}
