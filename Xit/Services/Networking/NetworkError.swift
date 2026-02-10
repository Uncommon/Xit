import Foundation

/// Errors that can occur during network operations.
enum NetworkError: Error {
  /// The URL could not be constructed from the endpoint configuration
  case invalidURL

  /// The server response was not a valid HTTP response
  case invalidResponse

  /// Authentication failed (HTTP 401)
  case unauthorized

  /// Server returned an error status code
  case serverError(Int)

  /// Failed to decode the response data
  case decodingError(Error)

  /// No data was returned from the server
  case noData

  /// The underlying request failed
  case requestFailed(Error)

  /// The request was cancelled
  case cancelled
}

extension NetworkError: LocalizedError
{
  var errorDescription: String?
  {
    switch self {
      case .invalidURL:
        "Invalid URL"
      case .invalidResponse:
        "Invalid server response"
      case .unauthorized:
        "Authentication failed"
      case .serverError(let code):
        "Server error: \(code)"
      case .decodingError(let error):
        "Failed to decode response: \(error.localizedDescription)"
      case .noData:
        "No data received from server"
      case .requestFailed(let error):
        "Request failed: \(error.localizedDescription)"
      case .cancelled:
        "Request was cancelled"
    }
  }
}
