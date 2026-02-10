import Foundation
@testable import Xit

/// Mock implementation of NetworkService for testing purposes.
/// Allows tests to inject predefined responses and verify requests.
final class MockNetworkService: NetworkService
{
  /// Recorded requests made through this service
  private(set) var requests: [Endpoint] = []
  
  /// Response to return for the next request
  var nextResponse: Result<Data, Error>?
  
  /// Queue of responses to return for subsequent requests
  var responseQueue: [Result<Data, Error>] = []
  
  /// Whether to clear the request history on each request
  var clearRequestsOnNext = false
  
  init()
  {
  }
  
  /// Makes a network request and decodes the response to the specified type.
  func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
  {
    let data = try await request(endpoint)
    let decoder = JSONDecoder()
    
    return try decoder.decode(T.self, from: data)
  }
  
  /// Makes a network request and returns raw data.
  func request(_ endpoint: Endpoint) async throws -> Data
  {
    if clearRequestsOnNext {
      requests.removeAll()
      clearRequestsOnNext = false
    }
    
    requests.append(endpoint)
    
    // Check for queued responses first
    if !responseQueue.isEmpty {
      let result = responseQueue.removeFirst()
      
      switch result {
        case .success(let data):
          return data
        case .failure(let error):
          throw error
      }
    }
    
    // Fall back to nextResponse
    guard let result = nextResponse
    else {
      throw NetworkError.noData
    }
    
    switch result {
      case .success(let data):
        return data
      case .failure(let error):
        throw error
    }
  }
  
  /// Sets the next response to return a successful data result.
  func setNextResponse(data: Data)
  {
    nextResponse = .success(data)
  }
  
  /// Sets the next response to return an error.
  func setNextResponse(error: Error)
  {
    nextResponse = .failure(error)
  }
  
  /// Enqueues a response to be returned in order.
  func enqueueResponse(data: Data)
  {
    responseQueue.append(.success(data))
  }
  
  /// Enqueues an error response to be returned in order.
  func enqueueResponse(error: Error)
  {
    responseQueue.append(.failure(error))
  }
  
  /// Resets all recorded requests and responses.
  func reset()
  {
    requests.removeAll()
    nextResponse = nil
    responseQueue.removeAll()
  }
  
  /// Verifies that a request was made matching the given predicate.
  func verifyRequest(_ predicate: (Endpoint) -> Bool) -> Bool
  {
    requests.contains(where: predicate)
  }
  
  /// Returns the last recorded request, if any.
  var lastRequest: Endpoint?
  {
    requests.last
  }
  
  /// Returns the number of requests recorded.
  var requestCount: Int
  {
    requests.count
  }
}
